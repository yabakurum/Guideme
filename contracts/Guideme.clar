(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_GUIDE_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_REGISTERED (err u102))
(define-constant ERR_INVALID_RATING (err u103))
(define-constant ERR_ALREADY_REVIEWED (err u104))
(define-constant ERR_GUIDE_NOT_ACTIVE (err u105))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u106))
(define-constant ERR_BOOKING_NOT_FOUND (err u107))
(define-constant ERR_BOOKING_ALREADY_CONFIRMED (err u108))
(define-constant ERR_BOOKING_NOT_CONFIRMED (err u109))
(define-constant ERR_BOOKING_CANCELLED (err u110))
(define-constant ERR_BOOKING_COMPLETED (err u111))
(define-constant ERR_INVALID_CANCELLATION (err u112))
(define-constant ERR_DISPUTE_PERIOD_EXPIRED (err u113))
(define-constant ERR_INVALID_SERVICE_TIER (err u114))
(define-constant ERR_BOOKING_NOT_ACTIVE (err u115))
(define-constant ERR_REFUND_ALREADY_PROCESSED (err u116))

(define-non-fungible-token guide-badge uint)
(define-non-fungible-token review-nft uint)
(define-non-fungible-token booking-nft uint)

(define-data-var next-guide-id uint u1)
(define-data-var next-review-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var registration-fee uint u1000000)
(define-data-var platform-fee-percent uint u5)
(define-data-var cancellation-window-blocks uint u144)
(define-data-var dispute-window-blocks uint u1008)

(define-map guides
  uint
  {
    owner: principal,
    name: (string-ascii 50),
    location: (string-ascii 100),
    specialties: (string-ascii 200),
    total-reviews: uint,
    average-rating: uint,
    total-rating-points: uint,
    is-active: bool,
    verified: bool
  }
)

(define-map reviews
  uint
  {
    guide-id: uint,
    reviewer: principal,
    rating: uint,
    comment: (string-ascii 500),
    timestamp: uint
  }
)

(define-map guide-owner-lookup principal uint)
(define-map user-guide-reviews {user: principal, guide: uint} uint)

(define-map service-tiers
  {guide-id: uint, tier: uint}
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    price: uint,
    duration-hours: uint,
    max-participants: uint,
    cancellation-fee-percent: uint,
    is-active: bool
  }
)

(define-map bookings
  uint
  {
    guide-id: uint,
    client: principal,
    service-tier: uint,
    total-amount: uint,
    guide-amount: uint,
    platform-fee: uint,
    booking-date: uint,
    service-date: uint,
    status: uint,
    cancellation-reason: (optional (string-ascii 200)),
    completion-confirmed: bool,
    refund-processed: bool,
    dispute-raised: bool,
    dispute-deadline: uint
  }
)

(define-map guide-service-tiers principal (list 5 uint))
(define-map booking-participants uint (list 20 principal))
(define-map guide-earnings principal uint)
(define-map platform-earnings principal uint)

(define-public (register-as-guide (name (string-ascii 50)) (location (string-ascii 100)) (specialties (string-ascii 200)))
  (let
    (
      (guide-id (var-get next-guide-id))
      (fee (var-get registration-fee))
    )
    (asserts! (is-none (map-get? guide-owner-lookup tx-sender)) ERR_ALREADY_REGISTERED)
    (try! (stx-transfer? fee tx-sender CONTRACT_OWNER))
    (try! (nft-mint? guide-badge guide-id tx-sender))
    (map-set guides guide-id
      {
        owner: tx-sender,
        name: name,
        location: location,
        specialties: specialties,
        total-reviews: u0,
        average-rating: u0,
        total-rating-points: u0,
        is-active: true,
        verified: false
      }
    )
    (map-set guide-owner-lookup tx-sender guide-id)
    (var-set next-guide-id (+ guide-id u1))
    (ok guide-id)
  )
)

(define-public (verify-guide (guide-id uint))
  (let
    (
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set guides guide-id
      (merge guide-data {verified: true})
    )
    (ok true)
  )
)

(define-public (deactivate-guide (guide-id uint))
  (let
    (
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner guide-data)) ERR_NOT_AUTHORIZED)
    (map-set guides guide-id
      (merge guide-data {is-active: false})
    )
    (ok true)
  )
)

(define-public (reactivate-guide (guide-id uint))
  (let
    (
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner guide-data)) ERR_NOT_AUTHORIZED)
    (map-set guides guide-id
      (merge guide-data {is-active: true})
    )
    (ok true)
  )
)

(define-public (submit-review (guide-id uint) (rating uint) (comment (string-ascii 500)))
  (let
    (
      (review-id (var-get next-review-id))
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
      (review-key {user: tx-sender, guide: guide-id})
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (get is-active guide-data) ERR_GUIDE_NOT_ACTIVE)
    (asserts! (is-none (map-get? user-guide-reviews review-key)) ERR_ALREADY_REVIEWED)
    
    (try! (nft-mint? review-nft review-id tx-sender))
    
    (map-set reviews review-id
      {
        guide-id: guide-id,
        reviewer: tx-sender,
        rating: rating,
        comment: comment,
        timestamp: stacks-block-height
      }
    )
    
    (map-set user-guide-reviews review-key review-id)
    
    (let
      (
        (new-total-reviews (+ (get total-reviews guide-data) u1))
        (new-total-points (+ (get total-rating-points guide-data) rating))
        (new-average (/ new-total-points new-total-reviews))
      )
      (map-set guides guide-id
        (merge guide-data
          {
            total-reviews: new-total-reviews,
            total-rating-points: new-total-points,
            average-rating: new-average
          }
        )
      )
    )
    
    (var-set next-review-id (+ review-id u1))
    (ok review-id)
  )
)

(define-public (update-guide-profile (name (string-ascii 50)) (location (string-ascii 100)) (specialties (string-ascii 200)))
  (let
    (
      (guide-id (unwrap! (map-get? guide-owner-lookup tx-sender) ERR_GUIDE_NOT_FOUND))
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
    )
    (map-set guides guide-id
      (merge guide-data
        {
          name: name,
          location: location,
          specialties: specialties
        }
      )
    )
    (ok true)
  )
)

(define-public (set-registration-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set registration-fee new-fee)
    (ok true)
  )
)

(define-read-only (get-guide (guide-id uint))
  (map-get? guides guide-id)
)

(define-read-only (get-review (review-id uint))
  (map-get? reviews review-id)
)

(define-read-only (get-guide-by-owner (owner principal))
  (match (map-get? guide-owner-lookup owner)
    guide-id (map-get? guides guide-id)
    none
  )
)

(define-read-only (get-user-review-for-guide (user principal) (guide-id uint))
  (match (map-get? user-guide-reviews {user: user, guide: guide-id})
    review-id (map-get? reviews review-id)
    none
  )
)

(define-read-only (get-registration-fee)
  (var-get registration-fee)
)

(define-read-only (get-next-guide-id)
  (var-get next-guide-id)
)

(define-read-only (get-next-review-id)
  (var-get next-review-id)
)

(define-read-only (get-guide-badge-owner (guide-id uint))
  (nft-get-owner? guide-badge guide-id)
)

(define-read-only (get-review-nft-owner (review-id uint))
  (nft-get-owner? review-nft review-id)
)

(define-read-only (is-guide-verified (guide-id uint))
  (match (map-get? guides guide-id)
    guide-data (get verified guide-data)
    false
  )
)

(define-read-only (is-guide-active (guide-id uint))
  (match (map-get? guides guide-id)
    guide-data (get is-active guide-data)
    false
  )
)

(define-read-only (get-guide-rating (guide-id uint))
  (match (map-get? guides guide-id)
    guide-data 
    {
      average-rating: (get average-rating guide-data),
      total-reviews: (get total-reviews guide-data)
    }
    {average-rating: u0, total-reviews: u0}
  )
)

(define-public (create-service-tier (guide-id uint) (tier uint) (name (string-ascii 50)) (description (string-ascii 200)) (price uint) (duration-hours uint) (max-participants uint) (cancellation-fee-percent uint))
  (let
    (
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
      (tier-key {guide-id: guide-id, tier: tier})
      (current-tiers (default-to (list) (map-get? guide-service-tiers tx-sender)))
    )
    (asserts! (is-eq tx-sender (get owner guide-data)) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= tier u1) (<= tier u5)) ERR_INVALID_SERVICE_TIER)
    (asserts! (<= cancellation-fee-percent u100) ERR_INVALID_CANCELLATION)
    (asserts! (is-none (map-get? service-tiers tier-key)) ERR_ALREADY_REGISTERED)
    
    (map-set service-tiers tier-key
      {
        name: name,
        description: description,
        price: price,
        duration-hours: duration-hours,
        max-participants: max-participants,
        cancellation-fee-percent: cancellation-fee-percent,
        is-active: true
      }
    )
    
    (map-set guide-service-tiers tx-sender
      (unwrap! (as-max-len? (append current-tiers tier) u5) ERR_INVALID_SERVICE_TIER)
    )
    
    (ok tier)
  )
)

(define-public (update-service-tier (guide-id uint) (tier uint) (name (string-ascii 50)) (description (string-ascii 200)) (price uint) (duration-hours uint) (max-participants uint) (cancellation-fee-percent uint))
  (let
    (
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
      (tier-key {guide-id: guide-id, tier: tier})
      (tier-data (unwrap! (map-get? service-tiers tier-key) ERR_INVALID_SERVICE_TIER))
    )
    (asserts! (is-eq tx-sender (get owner guide-data)) ERR_NOT_AUTHORIZED)
    (asserts! (<= cancellation-fee-percent u100) ERR_INVALID_CANCELLATION)
    
    (map-set service-tiers tier-key
      (merge tier-data
        {
          name: name,
          description: description,
          price: price,
          duration-hours: duration-hours,
          max-participants: max-participants,
          cancellation-fee-percent: cancellation-fee-percent
        }
      )
    )
    
    (ok true)
  )
)

(define-public (toggle-service-tier (guide-id uint) (tier uint))
  (let
    (
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
      (tier-key {guide-id: guide-id, tier: tier})
      (tier-data (unwrap! (map-get? service-tiers tier-key) ERR_INVALID_SERVICE_TIER))
    )
    (asserts! (is-eq tx-sender (get owner guide-data)) ERR_NOT_AUTHORIZED)
    
    (map-set service-tiers tier-key
      (merge tier-data {is-active: (not (get is-active tier-data))})
    )
    
    (ok (not (get is-active tier-data)))
  )
)

(define-public (create-booking (guide-id uint) (service-tier uint) (service-date uint) (participants (list 20 principal)))
  (let
    (
      (booking-id (var-get next-booking-id))
      (guide-data (unwrap! (map-get? guides guide-id) ERR_GUIDE_NOT_FOUND))
      (tier-key {guide-id: guide-id, tier: service-tier})
      (tier-data (unwrap! (map-get? service-tiers tier-key) ERR_INVALID_SERVICE_TIER))
      (participant-count (len participants))
      (platform-fee-rate (var-get platform-fee-percent))
      (tier-price (get price tier-data))
      (platform-fee (/ (* tier-price platform-fee-rate) u100))
      (guide-amount (- tier-price platform-fee))
      (dispute-deadline (+ stacks-block-height (var-get dispute-window-blocks)))
    )
    (asserts! (get is-active guide-data) ERR_GUIDE_NOT_ACTIVE)
    (asserts! (get is-active tier-data) ERR_INVALID_SERVICE_TIER)
    (asserts! (<= participant-count (get max-participants tier-data)) ERR_INSUFFICIENT_PAYMENT)
    (asserts! (> service-date stacks-block-height) ERR_INVALID_CANCELLATION)
    
    (try! (stx-transfer? tier-price tx-sender (as-contract tx-sender)))
    (try! (nft-mint? booking-nft booking-id tx-sender))
    
    (map-set bookings booking-id
      {
        guide-id: guide-id,
        client: tx-sender,
        service-tier: service-tier,
        total-amount: tier-price,
        guide-amount: guide-amount,
        platform-fee: platform-fee,
        booking-date: stacks-block-height,
        service-date: service-date,
        status: u1,
        cancellation-reason: none,
        completion-confirmed: false,
        refund-processed: false,
        dispute-raised: false,
        dispute-deadline: dispute-deadline
      }
    )
    
    (map-set booking-participants booking-id participants)
    (var-set next-booking-id (+ booking-id u1))
    
    (ok booking-id)
  )
)

(define-public (confirm-booking (booking-id uint))
  (let
    (
      (booking-data (unwrap! (map-get? bookings booking-id) ERR_BOOKING_NOT_FOUND))
      (guide-data (unwrap! (map-get? guides (get guide-id booking-data)) ERR_GUIDE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner guide-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status booking-data) u1) ERR_BOOKING_ALREADY_CONFIRMED)
    
    (map-set bookings booking-id
      (merge booking-data {status: u2})
    )
    
    (ok true)
  )
)

(define-public (cancel-booking (booking-id uint) (reason (string-ascii 200)))
  (let
    (
      (booking-data (unwrap! (map-get? bookings booking-id) ERR_BOOKING_NOT_FOUND))
      (guide-data (unwrap! (map-get? guides (get guide-id booking-data)) ERR_GUIDE_NOT_FOUND))
      (tier-key {guide-id: (get guide-id booking-data), tier: (get service-tier booking-data)})
      (tier-data (unwrap! (map-get? service-tiers tier-key) ERR_INVALID_SERVICE_TIER))
      (cancellation-window (var-get cancellation-window-blocks))
      (blocks-until-service (- (get service-date booking-data) stacks-block-height))
      (is-client (is-eq tx-sender (get client booking-data)))
      (is-guide (is-eq tx-sender (get owner guide-data)))
      (cancellation-fee-percent (get cancellation-fee-percent tier-data))
      (total-amount (get total-amount booking-data))
      (cancellation-fee (/ (* total-amount cancellation-fee-percent) u100))
      (refund-amount (- total-amount cancellation-fee))
    )
    (asserts! (or is-client is-guide) ERR_NOT_AUTHORIZED)
    (asserts! (or (is-eq (get status booking-data) u1) (is-eq (get status booking-data) u2)) ERR_BOOKING_NOT_ACTIVE)
    (asserts! (> blocks-until-service u0) ERR_INVALID_CANCELLATION)
    
    (if (and is-client (>= blocks-until-service cancellation-window))
      (try! (as-contract (stx-transfer? refund-amount tx-sender (get client booking-data))))
      (if (and is-client (< blocks-until-service cancellation-window))
        (begin
          (try! (as-contract (stx-transfer? refund-amount tx-sender (get client booking-data))))
          (try! (as-contract (stx-transfer? cancellation-fee tx-sender (get owner guide-data))))
        )
        (try! (as-contract (stx-transfer? total-amount tx-sender (get client booking-data))))
      )
    )
    
    (map-set bookings booking-id
      (merge booking-data
        {
          status: u4,
          cancellation-reason: (some reason),
          refund-processed: true
        }
      )
    )
    
    (ok true)
  )
)

(define-public (complete-service (booking-id uint))
  (let
    (
      (booking-data (unwrap! (map-get? bookings booking-id) ERR_BOOKING_NOT_FOUND))
      (guide-data (unwrap! (map-get? guides (get guide-id booking-data)) ERR_GUIDE_NOT_FOUND))
      (guide-amount (get guide-amount booking-data))
      (platform-fee (get platform-fee booking-data))
      (current-guide-earnings (default-to u0 (map-get? guide-earnings (get owner guide-data))))
      (current-platform-earnings (default-to u0 (map-get? platform-earnings CONTRACT_OWNER)))
    )
    (asserts! (is-eq tx-sender (get owner guide-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status booking-data) u2) ERR_BOOKING_NOT_CONFIRMED)
    (asserts! (<= (get service-date booking-data) stacks-block-height) ERR_INVALID_CANCELLATION)
    
    (try! (as-contract (stx-transfer? guide-amount tx-sender (get owner guide-data))))
    (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
    
    (map-set bookings booking-id
      (merge booking-data
        {
          status: u3,
          completion-confirmed: true
        }
      )
    )
    
    (map-set guide-earnings (get owner guide-data) (+ current-guide-earnings guide-amount))
    (map-set platform-earnings CONTRACT_OWNER (+ current-platform-earnings platform-fee))
    
    (ok true)
  )
)

(define-public (raise-dispute (booking-id uint) (reason (string-ascii 200)))
  (let
    (
      (booking-data (unwrap! (map-get? bookings booking-id) ERR_BOOKING_NOT_FOUND))
      (dispute-deadline (get dispute-deadline booking-data))
    )
    (asserts! (is-eq tx-sender (get client booking-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status booking-data) u2) ERR_BOOKING_NOT_CONFIRMED)
    (asserts! (<= stacks-block-height dispute-deadline) ERR_DISPUTE_PERIOD_EXPIRED)
    
    (map-set bookings booking-id
      (merge booking-data {dispute-raised: true})
    )
    
    (ok true)
  )
)

(define-public (resolve-dispute (booking-id uint) (favor-client bool))
  (let
    (
      (booking-data (unwrap! (map-get? bookings booking-id) ERR_BOOKING_NOT_FOUND))
      (guide-data (unwrap! (map-get? guides (get guide-id booking-data)) ERR_GUIDE_NOT_FOUND))
      (total-amount (get total-amount booking-data))
      (guide-amount (get guide-amount booking-data))
      (platform-fee (get platform-fee booking-data))
      (current-platform-earnings (default-to u0 (map-get? platform-earnings CONTRACT_OWNER)))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (get dispute-raised booking-data) ERR_BOOKING_NOT_FOUND)
    
    (if favor-client
      (try! (as-contract (stx-transfer? total-amount tx-sender (get client booking-data))))
      (begin
        (try! (as-contract (stx-transfer? guide-amount tx-sender (get owner guide-data))))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
      )
    )
    
    (map-set bookings booking-id
      (merge booking-data
        {
          status: u5,
          refund-processed: favor-client
        }
      )
    )
    
    (if (not favor-client)
      (map-set platform-earnings CONTRACT_OWNER (+ current-platform-earnings platform-fee))
      true
    )
    
    (ok favor-client)
  )
)

(define-public (set-platform-fee (new-fee-percent uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee-percent u50) ERR_INSUFFICIENT_PAYMENT)
    (var-set platform-fee-percent new-fee-percent)
    (ok true)
  )
)

(define-public (set-cancellation-window (new-window-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set cancellation-window-blocks new-window-blocks)
    (ok true)
  )
)

(define-public (set-dispute-window (new-window-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set dispute-window-blocks new-window-blocks)
    (ok true)
  )
)

(define-read-only (get-service-tier (guide-id uint) (tier uint))
  (map-get? service-tiers {guide-id: guide-id, tier: tier})
)

(define-read-only (get-guide-service-tiers (guide-owner principal))
  (map-get? guide-service-tiers guide-owner)
)

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings booking-id)
)

(define-read-only (get-booking-participants (booking-id uint))
  (map-get? booking-participants booking-id)
)

(define-read-only (get-guide-earnings (guide-owner principal))
  (default-to u0 (map-get? guide-earnings guide-owner))
)

(define-read-only (get-platform-earnings)
  (default-to u0 (map-get? platform-earnings CONTRACT_OWNER))
)

(define-read-only (get-booking-nft-owner (booking-id uint))
  (nft-get-owner? booking-nft booking-id)
)

(define-read-only (get-platform-fee-percent)
  (var-get platform-fee-percent)
)

(define-read-only (get-cancellation-window)
  (var-get cancellation-window-blocks)
)

(define-read-only (get-dispute-window)
  (var-get dispute-window-blocks)
)

(define-read-only (get-next-booking-id)
  (var-get next-booking-id)
)

(define-read-only (calculate-booking-cost (guide-id uint) (service-tier uint))
  (match (map-get? service-tiers {guide-id: guide-id, tier: service-tier})
    tier-data
    (let
      (
        (base-price (get price tier-data))
        (platform-fee (/ (* base-price (var-get platform-fee-percent)) u100))
      )
      (some {
        total-cost: base-price,
        guide-amount: (- base-price platform-fee),
        platform-fee: platform-fee
      })
    )
    none
  )
)