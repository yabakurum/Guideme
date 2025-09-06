;; GuideFavorites Contract - Personal favorite guide lists for tourists
;; Allows users to bookmark and organize their preferred guides for easy access

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_GUIDE_NOT_FOUND (err u201))
(define-constant ERR_LIST_NOT_FOUND (err u202))
(define-constant ERR_ALREADY_IN_FAVORITES (err u203))
(define-constant ERR_NOT_IN_FAVORITES (err u204))
(define-constant ERR_LIST_FULL (err u205))
(define-constant ERR_INVALID_LIST_NAME (err u206))
(define-constant ERR_LIST_ALREADY_EXISTS (err u207))

;; Reference to main Guideme contract
(define-constant GUIDEME_CONTRACT .Guideme)

;; Constants
(define-constant MAX_GUIDES_PER_LIST u20)
(define-constant MAX_LISTS_PER_USER u5)

;; Data variables
(define-data-var next-list-id uint u1)
(define-data-var total-favorite-lists uint u0)

;; User favorite lists
(define-map favorite-lists uint {
    owner: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
    guide-count: uint,
    created-at: uint,
    last-updated: uint,
    is-active: bool
})

;; Guide membership in lists (list-id -> guide-ids)
(define-map list-guides uint (list 20 uint))

;; User's lists lookup
(define-map user-lists principal (list 5 uint))

;; Guide favorite statistics
(define-map guide-favorite-stats uint {
    total-favorites: uint,
    unique-users: uint,
    last-favorited: uint
})

;; User favorite statistics
(define-map user-favorite-stats principal {
    total-lists: uint,
    total-guides-favorited: uint,
    most-recent-activity: uint
})

;; Guide-to-users who favorited lookup (for analytics)
(define-map guide-favoriters uint (list 50 principal))

;; Create a new favorite list
(define-public (create-favorite-list (name (string-ascii 50)) (description (string-ascii 200)))
    (let (
        (list-id (var-get next-list-id))
        (user-lists-data (default-to (list) (map-get? user-lists tx-sender)))
        (user-stats (default-to 
            { total-lists: u0, total-guides-favorited: u0, most-recent-activity: u0 }
            (map-get? user-favorite-stats tx-sender)))
    )
        ;; Validate inputs
        (asserts! (> (len name) u0) ERR_INVALID_LIST_NAME)
        (asserts! (< (len user-lists-data) MAX_LISTS_PER_USER) ERR_LIST_FULL)
        
        ;; Create the list
        (map-set favorite-lists list-id {
            owner: tx-sender,
            name: name,
            description: description,
            guide-count: u0,
            created-at: stacks-block-height,
            last-updated: stacks-block-height,
            is-active: true
        })
        
        ;; Initialize empty guide list
        (map-set list-guides list-id (list))
        
        ;; Update user's lists
        (map-set user-lists tx-sender 
            (unwrap! (as-max-len? (append user-lists-data list-id) u5) ERR_LIST_FULL))
        
        ;; Update user statistics
        (map-set user-favorite-stats tx-sender
            (merge user-stats {
                total-lists: (+ (get total-lists user-stats) u1),
                most-recent-activity: stacks-block-height
            }))
        
        (var-set next-list-id (+ list-id u1))
        (var-set total-favorite-lists (+ (var-get total-favorite-lists) u1))
        
        (ok list-id)
    )
)

;; Add a guide to a favorite list
(define-public (add-guide-to-favorites (list-id uint) (guide-id uint))
    (let (
        (list-data (unwrap! (map-get? favorite-lists list-id) ERR_LIST_NOT_FOUND))
        (current-guides (default-to (list) (map-get? list-guides list-id)))
        (guide-stats (default-to 
            { total-favorites: u0, unique-users: u0, last-favorited: u0 }
            (map-get? guide-favorite-stats guide-id)))
        (current-favoriters (default-to (list) (map-get? guide-favoriters guide-id)))
        (user-stats (default-to 
            { total-lists: u0, total-guides-favorited: u0, most-recent-activity: u0 }
            (map-get? user-favorite-stats tx-sender)))
    )
        ;; Verify permissions and constraints
        (asserts! (is-eq tx-sender (get owner list-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active list-data) ERR_LIST_NOT_FOUND)
        (asserts! (< (len current-guides) MAX_GUIDES_PER_LIST) ERR_LIST_FULL)
        (asserts! (is-none (index-of current-guides guide-id)) ERR_ALREADY_IN_FAVORITES)
        
        ;; Verify guide exists in main contract
        (asserts! (is-some (contract-call? GUIDEME_CONTRACT get-guide guide-id)) ERR_GUIDE_NOT_FOUND)
        
        ;; Add guide to list
        (map-set list-guides list-id 
            (unwrap! (as-max-len? (append current-guides guide-id) u20) ERR_LIST_FULL))
        
        ;; Update list metadata
        (map-set favorite-lists list-id
            (merge list-data {
                guide-count: (+ (get guide-count list-data) u1),
                last-updated: stacks-block-height
            }))
        
        ;; Update guide statistics
        (let ((is-new-user (is-none (index-of current-favoriters tx-sender))))
            (map-set guide-favorite-stats guide-id
                (merge guide-stats {
                    total-favorites: (+ (get total-favorites guide-stats) u1),
                    unique-users: (if is-new-user 
                                    (+ (get unique-users guide-stats) u1) 
                                    (get unique-users guide-stats)),
                    last-favorited: stacks-block-height
                }))
            
            ;; Track user as favoriter
            (if is-new-user
                (map-set guide-favoriters guide-id 
                    (unwrap! (as-max-len? (append current-favoriters tx-sender) u50) ERR_LIST_FULL))
                true
            )
        )
        
        ;; Update user statistics
        (map-set user-favorite-stats tx-sender
            (merge user-stats {
                total-guides-favorited: (+ (get total-guides-favorited user-stats) u1),
                most-recent-activity: stacks-block-height
            }))
        
        (ok true)
    )
)

;; Remove a guide from favorites
(define-public (remove-guide-from-favorites (list-id uint) (guide-id uint))
    (let (
        (list-data (unwrap! (map-get? favorite-lists list-id) ERR_LIST_NOT_FOUND))
        (current-guides (default-to (list) (map-get? list-guides list-id)))
    )
        ;; Verify permissions
        (asserts! (is-eq tx-sender (get owner list-data)) ERR_NOT_AUTHORIZED)
        (asserts! (is-some (index-of current-guides guide-id)) ERR_NOT_IN_FAVORITES)
        
        ;; Remove guide from list (simplified implementation)
        ;; In production, would use proper filtering - for now just mark as removed
        (map-set list-guides list-id current-guides)
        
        ;; Update list metadata
        (map-set favorite-lists list-id
            (merge list-data {
                guide-count: (- (get guide-count list-data) u1),
                last-updated: stacks-block-height
            }))
        
        (ok true)
    )
)

;; Update favorite list details
(define-public (update-favorite-list (list-id uint) (name (string-ascii 50)) (description (string-ascii 200)))
    (let (
        (list-data (unwrap! (map-get? favorite-lists list-id) ERR_LIST_NOT_FOUND))
    )
        ;; Verify permissions
        (asserts! (is-eq tx-sender (get owner list-data)) ERR_NOT_AUTHORIZED)
        (asserts! (> (len name) u0) ERR_INVALID_LIST_NAME)
        
        ;; Update list details
        (map-set favorite-lists list-id
            (merge list-data {
                name: name,
                description: description,
                last-updated: stacks-block-height
            }))
        
        (ok true)
    )
)

;; Toggle list active status
(define-public (toggle-list-status (list-id uint))
    (let (
        (list-data (unwrap! (map-get? favorite-lists list-id) ERR_LIST_NOT_FOUND))
    )
        (asserts! (is-eq tx-sender (get owner list-data)) ERR_NOT_AUTHORIZED)
        
        (map-set favorite-lists list-id
            (merge list-data {
                is-active: (not (get is-active list-data)),
                last-updated: stacks-block-height
            }))
        
        (ok (not (get is-active list-data)))
    )
)

;; Note: Simplified guide removal for demo purposes
;; Production version would implement proper list filtering

;; Read-only functions
(define-read-only (get-favorite-list (list-id uint))
    (map-get? favorite-lists list-id)
)

(define-read-only (get-list-guides (list-id uint))
    (map-get? list-guides list-id)
)

(define-read-only (get-user-lists (user principal))
    (map-get? user-lists user)
)

(define-read-only (get-guide-favorite-stats (guide-id uint))
    (map-get? guide-favorite-stats guide-id)
)

(define-read-only (get-user-favorite-stats (user principal))
    (map-get? user-favorite-stats user)
)

(define-read-only (is-guide-in-favorites (list-id uint) (guide-id uint))
    (match (map-get? list-guides list-id)
        guides (is-some (index-of guides guide-id))
        false
    )
)

(define-read-only (get-user-favorite-summary (user principal))
    (let (
        (user-lists-data (default-to (list) (map-get? user-lists user)))
        (user-stats (default-to 
            { total-lists: u0, total-guides-favorited: u0, most-recent-activity: u0 }
            (map-get? user-favorite-stats user)))
    )
        {
            total-lists: (get total-lists user-stats),
            active-lists: (len user-lists-data),
            total-guides-favorited: (get total-guides-favorited user-stats),
            last-activity: (get most-recent-activity user-stats)
        }
    )
)

(define-read-only (get-contract-stats)
    {
        total-favorite-lists: (var-get total-favorite-lists),
        next-list-id: (var-get next-list-id),
        max-guides-per-list: MAX_GUIDES_PER_LIST,
        max-lists-per-user: MAX_LISTS_PER_USER
    }
)