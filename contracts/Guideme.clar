(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_GUIDE_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_REGISTERED (err u102))
(define-constant ERR_INVALID_RATING (err u103))
(define-constant ERR_ALREADY_REVIEWED (err u104))
(define-constant ERR_GUIDE_NOT_ACTIVE (err u105))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u106))

(define-non-fungible-token guide-badge uint)
(define-non-fungible-token review-nft uint)

(define-data-var next-guide-id uint u1)
(define-data-var next-review-id uint u1)
(define-data-var registration-fee uint u1000000)

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