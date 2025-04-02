;; Identity Creation Contract
;; Establishes digital IDs for unbanked populations

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map identities
  { id: (string-ascii 36) }
  {
    owner: principal,
    created-at: uint,
    active: bool
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_REGISTERED u2)
(define-constant ERR_ID_NOT_FOUND u3)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Create a new identity
(define-public (create-identity (id (string-ascii 36)))
  (let (
    (existing-identity (map-get? identities { id: id }))
  )
    (asserts! (is-none existing-identity) (err ERR_ALREADY_REGISTERED))

    (map-set identities
      { id: id }
      {
        owner: tx-sender,
        created-at: block-height,
        active: true
      }
    )
    (ok true)
  )
)

;; Get identity information
(define-read-only (get-identity (id (string-ascii 36)))
  (map-get? identities { id: id })
)

;; Check if an identity exists and is active
(define-read-only (is-identity-active (id (string-ascii 36)))
  (match (map-get? identities { id: id })
    identity (get active identity)
    false
  )
)

;; Deactivate an identity (only owner or admin)
(define-public (deactivate-identity (id (string-ascii 36)))
  (let (
    (existing-identity (map-get? identities { id: id }))
  )
    (asserts! (is-some existing-identity) (err ERR_ID_NOT_FOUND))
    (asserts! (or
      (is-eq tx-sender (get owner (unwrap! existing-identity (err ERR_ID_NOT_FOUND))))
      (is-admin)
    ) (err ERR_UNAUTHORIZED))

    (map-set identities
      { id: id }
      (merge (unwrap! existing-identity (err ERR_ID_NOT_FOUND)) { active: false })
    )
    (ok true)
  )
)

;; Reactivate an identity (only owner or admin)
(define-public (reactivate-identity (id (string-ascii 36)))
  (let (
    (existing-identity (map-get? identities { id: id }))
  )
    (asserts! (is-some existing-identity) (err ERR_ID_NOT_FOUND))
    (asserts! (or
      (is-eq tx-sender (get owner (unwrap! existing-identity (err ERR_ID_NOT_FOUND))))
      (is-admin)
    ) (err ERR_UNAUTHORIZED))

    (map-set identities
      { id: id }
      (merge (unwrap! existing-identity (err ERR_ID_NOT_FOUND)) { active: true })
    )
    (ok true)
  )
)

;; Transfer admin rights (only current admin)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
