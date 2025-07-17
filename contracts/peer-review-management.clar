;; Peer Review Management Contract
;; Handles academic paper review processes and consensus mechanisms

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Review status constants
(define-constant STATUS-SUBMITTED u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-ACCEPTED u3)
(define-constant STATUS-REJECTED u4)
(define-constant STATUS-REVISION-REQUIRED u5)

;; Review decision constants
(define-constant DECISION-ACCEPT u1)
(define-constant DECISION-REJECT u2)
(define-constant DECISION-REVISE u3)

;; Data structures
(define-map papers uint {
  title: (string-ascii 300),
  abstract: (string-ascii 1000),
  author: principal,
  submission-block: uint,
  status: uint,
  review-count: uint,
  final-decision: (optional uint)
})

(define-map reviews {paper-id: uint, reviewer: principal} {
  decision: uint,
  score: uint,
  comments: (string-ascii 500),
  submission-block: uint,
  anonymous: bool
})

(define-map reviewers principal {
  expertise-areas: (string-ascii 200),
  review-count: uint,
  reputation: uint,
  active: bool
})

(define-map paper-assignments {paper-id: uint, reviewer: principal} {
  assigned-block: uint,
  completed: bool,
  deadline: uint
})

(define-data-var next-paper-id uint u1)
(define-data-var min-reviews-required uint u3)

;; Initialize contract owner as first reviewer
(map-set reviewers CONTRACT-OWNER {
  expertise-areas: "General",
  review-count: u0,
  reputation: u100,
  active: true
})

;; Public functions

;; Submit a paper for review
(define-public (submit-paper (title (string-ascii 300))
                            (abstract (string-ascii 1000)))
  (let ((paper-id (var-get next-paper-id)))
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len abstract) u0) ERR-INVALID-INPUT)

    (map-set papers paper-id {
      title: title,
      abstract: abstract,
      author: tx-sender,
      submission-block: block-height,
      status: STATUS-SUBMITTED,
      review-count: u0,
      final-decision: none
    })

    (var-set next-paper-id (+ paper-id u1))
    (ok paper-id)))

;; Register as a reviewer
(define-public (register-reviewer (expertise-areas (string-ascii 200)))
  (let ((existing-reviewer (map-get? reviewers tx-sender)))
    (asserts! (is-none existing-reviewer) ERR-ALREADY-EXISTS)
    (asserts! (> (len expertise-areas) u0) ERR-INVALID-INPUT)

    (map-set reviewers tx-sender {
      expertise-areas: expertise-areas,
      review-count: u0,
      reputation: u50,
      active: true
    })

    (ok true)))

;; Assign reviewer to paper (only contract owner or active reviewers)
(define-public (assign-reviewer (paper-id uint) (reviewer principal))
  (let ((paper-data (map-get? papers paper-id))
        (reviewer-data (map-get? reviewers reviewer))
        (assigner-data (map-get? reviewers tx-sender)))
    (asserts! (is-some paper-data) ERR-NOT-FOUND)
    (asserts! (is-some reviewer-data) ERR-NOT-FOUND)
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER)
                  (and (is-some assigner-data)
                       (get active (unwrap-panic assigner-data)))) ERR-NOT-AUTHORIZED)
    (asserts! (get active (unwrap-panic reviewer-data)) ERR-INVALID-INPUT)

    (let ((assignment-exists (is-some (map-get? paper-assignments {paper-id: paper-id, reviewer: reviewer}))))
      (asserts! (not assignment-exists) ERR-ALREADY-EXISTS)

      (map-set paper-assignments {paper-id: paper-id, reviewer: reviewer} {
        assigned-block: block-height,
        completed: false,
        deadline: (+ block-height u1000)
      })

      (ok true))))

;; Submit a review
(define-public (submit-review (paper-id uint)
                             (decision uint)
                             (score uint)
                             (comments (string-ascii 500))
                             (anonymous bool))
  (let ((paper-data (map-get? papers paper-id))
        (reviewer-data (map-get? reviewers tx-sender))
        (assignment-data (map-get? paper-assignments {paper-id: paper-id, reviewer: tx-sender})))
    (asserts! (is-some paper-data) ERR-NOT-FOUND)
    (asserts! (is-some reviewer-data) ERR-NOT-AUTHORIZED)
    (asserts! (is-some assignment-data) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= decision DECISION-ACCEPT) (<= decision DECISION-REVISE)) ERR-INVALID-INPUT)
    (asserts! (and (>= score u1) (<= score u10)) ERR-INVALID-INPUT)
    (asserts! (not (get completed (unwrap-panic assignment-data))) ERR-ALREADY-EXISTS)

    ;; Submit the review
    (map-set reviews {paper-id: paper-id, reviewer: tx-sender} {
      decision: decision,
      score: score,
      comments: comments,
      submission-block: block-height,
      anonymous: anonymous
    })

    ;; Mark assignment as completed
    (map-set paper-assignments {paper-id: paper-id, reviewer: tx-sender}
      (merge (unwrap-panic assignment-data) {completed: true}))

    ;; Update paper review count
    (let ((current-paper (unwrap-panic paper-data)))
      (map-set papers paper-id
        (merge current-paper {
          review-count: (+ (get review-count current-paper) u1),
          status: STATUS-UNDER-REVIEW
        })))

    ;; Update reviewer stats
    (let ((current-reviewer (unwrap-panic reviewer-data)))
      (map-set reviewers tx-sender
        (merge current-reviewer {
          review-count: (+ (get review-count current-reviewer) u1)
        })))

    (ok true)))

;; Finalize paper decision (only contract owner)
(define-public (finalize-decision (paper-id uint) (final-decision uint))
  (let ((paper-data (map-get? papers paper-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some paper-data) ERR-NOT-FOUND)
    (asserts! (>= (get review-count (unwrap-panic paper-data)) (var-get min-reviews-required)) ERR-INVALID-INPUT)
    (asserts! (and (>= final-decision STATUS-ACCEPTED) (<= final-decision STATUS-REVISION-REQUIRED)) ERR-INVALID-INPUT)

    (map-set papers paper-id
      (merge (unwrap-panic paper-data) {
        status: final-decision,
        final-decision: (some final-decision)
      }))

    (ok true)))

;; Update reviewer status (only contract owner)
(define-public (update-reviewer-status (reviewer principal) (active bool))
  (let ((reviewer-data (map-get? reviewers reviewer)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some reviewer-data) ERR-NOT-FOUND)

    (map-set reviewers reviewer
      (merge (unwrap-panic reviewer-data) {active: active}))

    (ok true)))

;; Read-only functions

;; Get paper information
(define-read-only (get-paper (paper-id uint))
  (map-get? papers paper-id))

;; Get review information
(define-read-only (get-review (paper-id uint) (reviewer principal))
  (map-get? reviews {paper-id: paper-id, reviewer: reviewer}))

;; Get reviewer information
(define-read-only (get-reviewer (reviewer principal))
  (map-get? reviewers reviewer))

;; Get assignment information
(define-read-only (get-assignment (paper-id uint) (reviewer principal))
  (map-get? paper-assignments {paper-id: paper-id, reviewer: reviewer}))

;; Check if reviewer is active
(define-read-only (is-active-reviewer (reviewer principal))
  (match (map-get? reviewers reviewer)
    reviewer-data (get active reviewer-data)
    false))

;; Get minimum reviews required
(define-read-only (get-min-reviews-required)
  (var-get min-reviews-required))
