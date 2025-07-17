;; Data Sharing Agreement Contract
;; Controls research data access permissions and usage tracking

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Access level constants
(define-constant ACCESS-READ u1)
(define-constant ACCESS-WRITE u2)
(define-constant ACCESS-ADMIN u3)

;; Data structures
(define-map datasets uint {
  title: (string-ascii 200),
  description: (string-ascii 500),
  owner: principal,
  creation-block: uint,
  public-access: bool,
  download-count: uint
})

(define-map data-access {dataset-id: uint, user: principal} {
  access-level: uint,
  granted-block: uint,
  granted-by: principal,
  usage-count: uint,
  last-access: uint
})

(define-map usage-logs uint {
  dataset-id: uint,
  user: principal,
  access-type: uint,
  timestamp: uint,
  details: (string-ascii 200)
})

(define-data-var next-dataset-id uint u1)
(define-data-var next-log-id uint u1)

;; Public functions

;; Register a new dataset
(define-public (register-dataset (title (string-ascii 200))
                                (description (string-ascii 500))
                                (public-access bool))
  (let ((dataset-id (var-get next-dataset-id)))
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set datasets dataset-id {
      title: title,
      description: description,
      owner: tx-sender,
      creation-block: block-height,
      public-access: public-access,
      download-count: u0
    })

    ;; Grant admin access to owner
    (map-set data-access {dataset-id: dataset-id, user: tx-sender} {
      access-level: ACCESS-ADMIN,
      granted-block: block-height,
      granted-by: tx-sender,
      usage-count: u0,
      last-access: block-height
    })

    (var-set next-dataset-id (+ dataset-id u1))
    (ok dataset-id)))

;; Grant access to a dataset
(define-public (grant-access (dataset-id uint) (user principal) (access-level uint))
  (let ((dataset-data (map-get? datasets dataset-id))
        (grantor-access (map-get? data-access {dataset-id: dataset-id, user: tx-sender})))
    (asserts! (is-some dataset-data) ERR-NOT-FOUND)
    (asserts! (is-some grantor-access) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get access-level (unwrap-panic grantor-access)) ACCESS-ADMIN) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= access-level ACCESS-READ) (<= access-level ACCESS-ADMIN)) ERR-INVALID-INPUT)

    (map-set data-access {dataset-id: dataset-id, user: user} {
      access-level: access-level,
      granted-block: block-height,
      granted-by: tx-sender,
      usage-count: u0,
      last-access: block-height
    })

    (ok true)))

;; Revoke access to a dataset
(define-public (revoke-access (dataset-id uint) (user principal))
  (let ((dataset-data (map-get? datasets dataset-id))
        (grantor-access (map-get? data-access {dataset-id: dataset-id, user: tx-sender})))
    (asserts! (is-some dataset-data) ERR-NOT-FOUND)
    (asserts! (is-some grantor-access) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get access-level (unwrap-panic grantor-access)) ACCESS-ADMIN) ERR-NOT-AUTHORIZED)

    (map-delete data-access {dataset-id: dataset-id, user: user})
    (ok true)))

;; Log data usage
(define-public (log-usage (dataset-id uint) (access-type uint) (details (string-ascii 200)))
  (let ((dataset-data (map-get? datasets dataset-id))
        (user-access (map-get? data-access {dataset-id: dataset-id, user: tx-sender}))
        (log-id (var-get next-log-id)))
    (asserts! (is-some dataset-data) ERR-NOT-FOUND)
    (asserts! (or (is-some user-access)
                  (get public-access (unwrap-panic dataset-data))) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= access-type u1) (<= access-type u3)) ERR-INVALID-INPUT)

    ;; Update usage count if user has explicit access
    (match user-access
      access-data (map-set data-access {dataset-id: dataset-id, user: tx-sender}
                    (merge access-data {
                      usage-count: (+ (get usage-count access-data) u1),
                      last-access: block-height
                    }))
      true)

    ;; Update dataset download count
    (map-set datasets dataset-id
      (merge (unwrap-panic dataset-data) {
        download-count: (+ (get download-count (unwrap-panic dataset-data)) u1)
      }))

    ;; Log the usage
    (map-set usage-logs log-id {
      dataset-id: dataset-id,
      user: tx-sender,
      access-type: access-type,
      timestamp: block-height,
      details: details
    })

    (var-set next-log-id (+ log-id u1))
    (ok log-id)))

;; Update dataset visibility
(define-public (update-dataset-visibility (dataset-id uint) (public-access bool))
  (let ((dataset-data (map-get? datasets dataset-id)))
    (asserts! (is-some dataset-data) ERR-NOT-FOUND)
    (asserts! (is-eq tx-sender (get owner (unwrap-panic dataset-data))) ERR-NOT-AUTHORIZED)

    (map-set datasets dataset-id
      (merge (unwrap-panic dataset-data) {public-access: public-access}))

    (ok true)))

;; Read-only functions

;; Get dataset information
(define-read-only (get-dataset (dataset-id uint))
  (map-get? datasets dataset-id))

;; Get user access level for a dataset
(define-read-only (get-user-access (dataset-id uint) (user principal))
  (map-get? data-access {dataset-id: dataset-id, user: user}))

;; Check if user has access to dataset
(define-read-only (has-access (dataset-id uint) (user principal) (required-level uint))
  (match (map-get? datasets dataset-id)
    dataset-data
      (if (get public-access dataset-data)
        (>= ACCESS-READ required-level)
        (match (map-get? data-access {dataset-id: dataset-id, user: user})
          access-data (>= (get access-level access-data) required-level)
          false))
    false))

;; Get usage log
(define-read-only (get-usage-log (log-id uint))
  (map-get? usage-logs log-id))

;; Get next dataset ID
(define-read-only (get-next-dataset-id)
  (var-get next-dataset-id))
