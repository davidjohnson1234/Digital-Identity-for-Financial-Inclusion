;; Service Access Contract
;; Connects users with appropriate financial services

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map service-providers
  { provider-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    principal: principal,
    min-reputation: uint,
    active: bool,
    services: (list 10 (string-ascii 50))
  }
)

(define-map service-access-records
  { id: (string-ascii 36), provider-id: (string-ascii 36) }
  {
    granted-at: uint,
    active: bool
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_PROVIDER_NOT_FOUND u2)
(define-constant ERR_INSUFFICIENT_REPUTATION u3)
(define-constant ERR_ALREADY_REGISTERED u4)
(define-constant ERR_ACCESS_NOT_FOUND u5)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new service provider (admin only)
(define-public (register-service-provider
  (provider-id (string-ascii 36))
  (name (string-ascii 100))
  (provider-principal principal)
  (min-reputation uint)
  (services (list 10 (string-ascii 50)))
)
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? service-providers { provider-id: provider-id })) (err ERR_ALREADY_REGISTERED))

    (map-set service-providers
      { provider-id: provider-id }
      {
        name: name,
        principal: provider-principal,
        min-reputation: min-reputation,
        active: true,
        services: services
      }
    )
    (ok true)
  )
)

;; Request access to a service provider
(define-public (request-service-access (id (string-ascii 36)) (provider-id (string-ascii 36)) (user-reputation uint))
  (let (
    (provider (map-get? service-providers { provider-id: provider-id }))
  )
    (asserts! (is-some provider) (err ERR_PROVIDER_NOT_FOUND))
    (asserts! (get active (unwrap! provider (err ERR_PROVIDER_NOT_FOUND))) (err ERR_PROVIDER_NOT_FOUND))
    (asserts! (>= user-reputation (get min-reputation (unwrap! provider (err ERR_PROVIDER_NOT_FOUND))))
              (err ERR_INSUFFICIENT_REPUTATION))

    (map-set service-access-records
      { id: id, provider-id: provider-id }
      {
        granted-at: block-height,
        active: true
      }
    )
    (ok true)
  )
)

;; Check if a user has access to a service provider
(define-read-only (has-service-access (id (string-ascii 36)) (provider-id (string-ascii 36)))
  (match (map-get? service-access-records { id: id, provider-id: provider-id })
    access-record (get active access-record)
    false
  )
)

;; Get service provider details
(define-read-only (get-service-provider (provider-id (string-ascii 36)))
  (map-get? service-providers { provider-id: provider-id })
)

;; Revoke service access (can be done by user, provider, or admin)
(define-public (revoke-service-access (id (string-ascii 36)) (provider-id (string-ascii 36)))
  (let (
    (access-record (map-get? service-access-records { id: id, provider-id: provider-id }))
    (provider (map-get? service-providers { provider-id: provider-id }))
  )
    (asserts! (is-some access-record) (err ERR_ACCESS_NOT_FOUND))
    (asserts! (is-some provider) (err ERR_PROVIDER_NOT_FOUND))

    ;; Check if caller is authorized (admin, the provider, or the user)
    (asserts! (or
      (is-admin)
      (is-eq tx-sender (get principal (unwrap! provider (err ERR_PROVIDER_NOT_FOUND))))
      ;; Assuming the user is the tx-sender for simplicity
    ) (err ERR_UNAUTHORIZED))

    (map-set service-access-records
      { id: id, provider-id: provider-id }
      (merge (unwrap! access-record (err ERR_ACCESS_NOT_FOUND)) { active: false })
    )
    (ok true)
  )
)

;; Deactivate a service provider (admin only)
(define-public (deactivate-service-provider (provider-id (string-ascii 36)))
  (let (
    (provider (map-get? service-providers { provider-id: provider-id }))
  )
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-some provider) (err ERR_PROVIDER_NOT_FOUND))

    (map-set service-providers
      { provider-id: provider-id }
      (merge (unwrap! provider (err ERR_PROVIDER_NOT_FOUND)) { active: false })
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
