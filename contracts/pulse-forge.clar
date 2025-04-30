;; PulseForge Workflow Management
;; A decentralized workflow management system for team coordination, project tracking, and team communication
;; Built on Stacks blockchain for transparency, accountability and immutability

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROJECT-NOT-FOUND (err u101))
(define-constant ERR-MILESTONE-NOT-FOUND (err u102))
(define-constant ERR-TASK-NOT-FOUND (err u103))
(define-constant ERR-INVALID-DEADLINE (err u104))
(define-constant ERR-USER-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-EXISTS (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-INVALID-ROLE (err u108))
(define-constant ERR-DEPENDENCY-INCOMPLETE (err u109))

;; Status constants
(define-constant STATUS-PENDING u1)
(define-constant STATUS-IN-PROGRESS u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-DELAYED u4)
(define-constant STATUS-CANCELLED u5)

;; Role constants
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-MEMBER u2)
(define-constant ROLE-VIEWER u3)

;; Data structures

;; Stores project information
(define-map projects
  { project-id: uint }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    creator: principal,
    created-at: uint,
    status: uint,
    deadline: uint
  }
)

;; Tracks all project IDs
(define-data-var next-project-id uint u1)

;; Stores milestone information
(define-map milestones
  { project-id: uint, milestone-id: uint }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    deadline: uint,
    status: uint
  }
)

;; Tracks milestone IDs per project
(define-map project-milestone-count
  { project-id: uint }
  { count: uint }
)

;; Stores task information
(define-map tasks
  { project-id: uint, milestone-id: uint, task-id: uint }
  {
    name: (string-ascii 100),
    description: (string-utf8 500),
    assignee: (optional principal),
    deadline: uint,
    status: uint,
    dependencies: (list 10 uint)
  }
)

;; Tracks task IDs per milestone
(define-map milestone-task-count
  { project-id: uint, milestone-id: uint }
  { count: uint }
)

;; Stores team member associations and roles
(define-map team-members
  { project-id: uint, member: principal }
  { role: uint }
)

;; Stores update and communication history
(define-map communications
  { project-id: uint, comm-id: uint }
  {
    sender: principal,
    timestamp: uint,
    message: (string-utf8 1000),
    context-type: (string-ascii 20), ;; "project", "milestone", or "task"
    context-id: uint                 ;; project-id, milestone-id, or task-id
  }
)

;; Tracks communication IDs per project
(define-map project-comm-count
  { project-id: uint }
  { count: uint }
)

;; Private functions

;; Helper to check if user is authorized for a specific role
(define-private (is-authorized (project-id uint) (required-role uint))
  (let (
    (user-role (get role (default-to { role: u0 } (map-get? team-members { project-id: project-id, member: tx-sender }))))
    (is-creator (is-eq tx-sender (get creator (unwrap! (map-get? projects { project-id: project-id }) false))))
  )
    (or is-creator (<= required-role user-role))
  )
)

;; Helper to validate task dependencies are completed
(define-private (are-dependencies-completed (project-id uint) (milestone-id uint) (dependencies (list 10 uint)))
  (let (
    (incomplete-count (fold check-dependency u0 dependencies))
  )
    (is-eq incomplete-count u0)
  )

  (define-private (check-dependency (dep-id uint) (acc uint))
    (let (
      (task-status (get status (default-to 
                                { status: u0 } 
                                (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: dep-id }))))
    )
      (if (is-eq task-status STATUS-COMPLETED)
        acc
        (+ acc u1))
    )
  )
)

;; Helper to check if deadline is valid (in the future)
(define-private (is-valid-deadline (deadline uint))
  (> deadline block-height)
)

;; Read-only functions

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

;; Get milestone details
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones { project-id: project-id, milestone-id: milestone-id })
)

;; Get task details
(define-read-only (get-task (project-id uint) (milestone-id uint) (task-id uint))
  (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: task-id })
)

;; Get team member role
(define-read-only (get-member-role (project-id uint) (member principal))
  (map-get? team-members { project-id: project-id, member: member })
)

;; Get project milestones
(define-read-only (get-project-milestones (project-id uint))
  (let (
    (milestone-count (get count (default-to { count: u0 } (map-get? project-milestone-count { project-id: project-id }))))
  )
    (filter-milestones project-id milestone-count)
  )

  (define-private (filter-milestones (project-id uint) (count uint))
    (map 
      (lambda (milestone-id) 
        {
          milestone-id: milestone-id,
          milestone: (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) none)
        }
      )
      (generate-milestone-ids count)
    )
  )

  (define-private (generate-milestone-ids (count uint))
    (map 
      (lambda (id) (+ id u1))
      (list-range-get u0 (- count u1))
    )
  )

  (define-private (list-range-get (start uint) (end uint))
    ;; Note: This is a simplified version since Clarity doesn't have direct range function
    ;; In a real implementation, you'd need a more robust approach for large lists
    (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
  )
)

;; Get milestone tasks
(define-read-only (get-milestone-tasks (project-id uint) (milestone-id uint))
  (let (
    (task-count (get count (default-to { count: u0 } (map-get? milestone-task-count { project-id: project-id, milestone-id: milestone-id }))))
  )
    (filter-tasks project-id milestone-id task-count)
  )

  (define-private (filter-tasks (project-id uint) (milestone-id uint) (count uint))
    (map 
      (lambda (task-id) 
        {
          task-id: task-id,
          task: (unwrap! (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: task-id }) none)
        }
      )
      (generate-task-ids count)
    )
  )

  (define-private (generate-task-ids (count uint))
    (map 
      (lambda (id) (+ id u1))
      (list-range-get u0 (- count u1))
    )
  )
)

;; Get project communications
(define-read-only (get-project-communications (project-id uint))
  (let (
    (comm-count (get count (default-to { count: u0 } (map-get? project-comm-count { project-id: project-id }))))
  )
    (filter-communications project-id comm-count)
  )

  (define-private (filter-communications (project-id uint) (count uint))
    (map 
      (lambda (comm-id) 
        {
          comm-id: comm-id,
          communication: (unwrap! (map-get? communications { project-id: project-id, comm-id: comm-id }) none)
        }
      )
      (generate-comm-ids count)
    )
  )

  (define-private (generate-comm-ids (count uint))
    (map 
      (lambda (id) (+ id u1))
      (list-range-get u0 (- count u1))
    )
  )
)

;; Filter tasks by assignee
(define-read-only (get-tasks-by-assignee (project-id uint) (assignee principal))
  ;; In a production environment, this would need a more efficient implementation
  ;; using indexers or off-chain storage with on-chain verification
  (let (
    (milestone-count (get count (default-to { count: u0 } (map-get? project-milestone-count { project-id: project-id }))))
  )
    (fold collect-assignee-tasks [] (generate-milestone-ids milestone-count))
  )

  (define-private (collect-assignee-tasks (milestone-id uint) (acc (list 100 {
    project-id: uint,
    milestone-id: uint,
    task-id: uint,
    task: {
      name: (string-ascii 100),
      description: (string-utf8 500),
      assignee: (optional principal),
      deadline: uint,
      status: uint,
      dependencies: (list 10 uint)
    }
  })))
    (let (
      (task-count (get count (default-to { count: u0 } (map-get? milestone-task-count { project-id: project-id, milestone-id: milestone-id }))))
    )
      (fold 
        (check-and-add-task project-id milestone-id assignee) 
        acc 
        (generate-task-ids task-count)
      )
    )
  )

  (define-private (check-and-add-task (project-id uint) (milestone-id uint) (assignee principal) (task-id uint) (acc (list 100 {
    project-id: uint,
    milestone-id: uint,
    task-id: uint,
    task: {
      name: (string-ascii 100),
      description: (string-utf8 500),
      assignee: (optional principal),
      deadline: uint,
      status: uint,
      dependencies: (list 10 uint)
    }
  })))
    (let (
      (task (default-to 
              {
                name: "", 
                description: "", 
                assignee: none, 
                deadline: u0, 
                status: u0, 
                dependencies: (list)
              } 
              (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: task-id })))
    )
      (if (is-eq (some assignee) (get assignee task))
        (append acc {
          project-id: project-id,
          milestone-id: milestone-id,
          task-id: task-id,
          task: task
        })
        acc
      )
    )
  )
)

;; Filter tasks by deadline approaching (within next N blocks)
(define-read-only (get-upcoming-deadlines (project-id uint) (blocks-window uint))
  (let (
    (current-block block-height)
    (deadline-threshold (+ current-block blocks-window))
    (milestone-count (get count (default-to { count: u0 } (map-get? project-milestone-count { project-id: project-id }))))
  )
    (fold collect-upcoming-tasks [] (generate-milestone-ids milestone-count))
  )

  (define-private (collect-upcoming-tasks (milestone-id uint) (acc (list 100 {
    project-id: uint,
    milestone-id: uint,
    task-id: uint,
    task: {
      name: (string-ascii 100),
      description: (string-utf8 500),
      assignee: (optional principal),
      deadline: uint,
      status: uint,
      dependencies: (list 10 uint)
    }
  })))
    (let (
      (task-count (get count (default-to { count: u0 } (map-get? milestone-task-count { project-id: project-id, milestone-id: milestone-id }))))
    )
      (fold 
        (check-and-add-upcoming-task project-id milestone-id deadline-threshold) 
        acc 
        (generate-task-ids task-count)
      )
    )
  )

  (define-private (check-and-add-upcoming-task (project-id uint) (milestone-id uint) (deadline-threshold uint) (task-id uint) (acc (list 100 {
    project-id: uint,
    milestone-id: uint,
    task-id: uint,
    task: {
      name: (string-ascii 100),
      description: (string-utf8 500),
      assignee: (optional principal),
      deadline: uint,
      status: uint,
      dependencies: (list 10 uint)
    }
  })))
    (let (
      (task (default-to 
              {
                name: "", 
                description: "", 
                assignee: none, 
                deadline: u0, 
                status: u0, 
                dependencies: (list)
              } 
              (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: task-id })))
      (task-deadline (get deadline task))
    )
      (if (and 
            (< task-deadline deadline-threshold) 
            (> task-deadline block-height)
            (not (is-eq (get status task) STATUS-COMPLETED))
            (not (is-eq (get status task) STATUS-CANCELLED))
          )
        (append acc {
          project-id: project-id,
          milestone-id: milestone-id,
          task-id: task-id,
          task: task
        })
        acc
      )
    )
  )
)

;; Public functions

;; Create a new project
(define-public (create-project (name (string-ascii 100)) (description (string-utf8 500)) (deadline uint))
  (let (
    (project-id (var-get next-project-id))
  )
    ;; Verify deadline is in the future
    (asserts! (is-valid-deadline deadline) ERR-INVALID-DEADLINE)
    
    ;; Store project data
    (map-set projects 
      { project-id: project-id }
      {
        name: name,
        description: description,
        creator: tx-sender,
        created-at: block-height,
        status: STATUS-PENDING,
        deadline: deadline
      }
    )
    
    ;; Initialize project milestone count
    (map-set project-milestone-count
      { project-id: project-id }
      { count: u0 }
    )
    
    ;; Initialize project communication count
    (map-set project-comm-count
      { project-id: project-id }
      { count: u0 }
    )
    
    ;; Add creator as admin
    (map-set team-members
      { project-id: project-id, member: tx-sender }
      { role: ROLE-ADMIN }
    )
    
    ;; Increment project counter
    (var-set next-project-id (+ project-id u1))
    
    (ok project-id)
  )
)

;; Add a team member to a project
(define-public (add-team-member (project-id uint) (member principal) (role uint))
  (begin
    ;; Ensure project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Check authorization - only admins can add members
    (asserts! (is-authorized project-id ROLE-ADMIN) ERR-NOT-AUTHORIZED)
    
    ;; Validate role
    (asserts! (or (is-eq role ROLE-ADMIN) (is-eq role ROLE-MEMBER) (is-eq role ROLE-VIEWER)) ERR-INVALID-ROLE)
    
    ;; Check if the member is already on the team
    (asserts! (is-none (map-get? team-members { project-id: project-id, member: member })) ERR-ALREADY-EXISTS)
    
    ;; Add member with specified role
    (map-set team-members
      { project-id: project-id, member: member }
      { role: role }
    )
    
    (ok true)
  )
)

;; Create a new milestone for a project
(define-public (create-milestone (project-id uint) (name (string-ascii 100)) (description (string-utf8 500)) (deadline uint))
  (let (
    (milestone-count-data (default-to { count: u0 } (map-get? project-milestone-count { project-id: project-id })))
    (milestone-count (get count milestone-count-data))
    (new-milestone-id (+ milestone-count u1))
  )
    ;; Ensure project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Check authorization - only admins can create milestones
    (asserts! (is-authorized project-id ROLE-ADMIN) ERR-NOT-AUTHORIZED)
    
    ;; Verify deadline is in the future
    (asserts! (is-valid-deadline deadline) ERR-INVALID-DEADLINE)
    
    ;; Store milestone data
    (map-set milestones
      { project-id: project-id, milestone-id: new-milestone-id }
      {
        name: name,
        description: description,
        deadline: deadline,
        status: STATUS-PENDING
      }
    )
    
    ;; Initialize milestone task count
    (map-set milestone-task-count
      { project-id: project-id, milestone-id: new-milestone-id }
      { count: u0 }
    )
    
    ;; Update milestone count
    (map-set project-milestone-count
      { project-id: project-id }
      { count: new-milestone-id }
    )
    
    (ok new-milestone-id)
  )
)

;; Create a new task for a milestone
(define-public (create-task 
  (project-id uint) 
  (milestone-id uint) 
  (name (string-ascii 100)) 
  (description (string-utf8 500)) 
  (deadline uint)
  (dependencies (list 10 uint))
)
  (let (
    (task-count-data (default-to { count: u0 } (map-get? milestone-task-count { project-id: project-id, milestone-id: milestone-id })))
    (task-count (get count task-count-data))
    (new-task-id (+ task-count u1))
  )
    ;; Ensure project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Ensure milestone exists
    (asserts! (is-some (map-get? milestones { project-id: project-id, milestone-id: milestone-id })) ERR-MILESTONE-NOT-FOUND)
    
    ;; Check authorization - admin or team member
    (asserts! (is-authorized project-id ROLE-MEMBER) ERR-NOT-AUTHORIZED)
    
    ;; Verify deadline is in the future
    (asserts! (is-valid-deadline deadline) ERR-INVALID-DEADLINE)
    
    ;; Store task data
    (map-set tasks
      { project-id: project-id, milestone-id: milestone-id, task-id: new-task-id }
      {
        name: name,
        description: description,
        assignee: none,
        deadline: deadline,
        status: STATUS-PENDING,
        dependencies: dependencies
      }
    )
    
    ;; Update task count
    (map-set milestone-task-count
      { project-id: project-id, milestone-id: milestone-id }
      { count: new-task-id }
    )
    
    (ok new-task-id)
  )
)

;; Assign a task to a team member
(define-public (assign-task (project-id uint) (milestone-id uint) (task-id uint) (assignee principal))
  (let (
    (task (unwrap! (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: task-id }) ERR-TASK-NOT-FOUND))
  )
    ;; Ensure project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Check authorization - admin or current assignee can change assignment
    (asserts! 
      (or 
        (is-authorized project-id ROLE-ADMIN)
        (is-eq (some tx-sender) (get assignee task))
      ) 
      ERR-NOT-AUTHORIZED
    )
    
    ;; Ensure assignee is a team member
    (asserts! (is-some (map-get? team-members { project-id: project-id, member: assignee })) ERR-USER-NOT-FOUND)
    
    ;; Update task assignment
    (map-set tasks
      { project-id: project-id, milestone-id: milestone-id, task-id: task-id }
      (merge task { assignee: (some assignee) })
    )
    
    (ok true)
  )
)

;; Update task status
(define-public (update-task-status (project-id uint) (milestone-id uint) (task-id uint) (new-status uint))
  (let (
    (task (unwrap! (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: task-id }) ERR-TASK-NOT-FOUND))
  )
    ;; Ensure project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Check authorization - admin or assignee
    (asserts! 
      (or 
        (is-authorized project-id ROLE-ADMIN)
        (is-eq (some tx-sender) (get assignee task))
      ) 
      ERR-NOT-AUTHORIZED
    )
    
    ;; Validate status code
    (asserts! 
      (or 
        (is-eq new-status STATUS-PENDING)
        (is-eq new-status STATUS-IN-PROGRESS)
        (is-eq new-status STATUS-COMPLETED)
        (is-eq new-status STATUS-DELAYED)
        (is-eq new-status STATUS-CANCELLED)
      ) 
      ERR-INVALID-STATUS
    )
    
    ;; If completing, check dependencies
    (if (is-eq new-status STATUS-COMPLETED)
        (asserts! (are-dependencies-completed project-id milestone-id (get dependencies task)) ERR-DEPENDENCY-INCOMPLETE)
        true
    )
    
    ;; Update task status
    (map-set tasks
      { project-id: project-id, milestone-id: milestone-id, task-id: task-id }
      (merge task { status: new-status })
    )
    
    ;; Check if all tasks in milestone are complete and update milestone if needed
    (if (is-eq new-status STATUS-COMPLETED)
        (try! (check-and-update-milestone-status project-id milestone-id))
        (ok true)
    )
  )
)

;; Update milestone status
(define-public (update-milestone-status (project-id uint) (milestone-id uint) (new-status uint))
  (let (
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
  )
    ;; Ensure project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Check authorization - only admins can update milestone status
    (asserts! (is-authorized project-id ROLE-ADMIN) ERR-NOT-AUTHORIZED)
    
    ;; Validate status code
    (asserts! 
      (or 
        (is-eq new-status STATUS-PENDING)
        (is-eq new-status STATUS-IN-PROGRESS)
        (is-eq new-status STATUS-COMPLETED)
        (is-eq new-status STATUS-DELAYED)
        (is-eq new-status STATUS-CANCELLED)
      ) 
      ERR-INVALID-STATUS
    )
    
    ;; Update milestone status
    (map-set milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone { status: new-status })
    )
    
    ;; Check if all milestones in project are complete and update project if needed
    (if (is-eq new-status STATUS-COMPLETED)
        (try! (check-and-update-project-status project-id))
        (ok true)
    )
  )
)

;; Helper to check and update milestone status when all tasks are complete
(define-public (check-and-update-milestone-status (project-id uint) (milestone-id uint))
  (let (
    (task-count (get count (default-to { count: u0 } (map-get? milestone-task-count { project-id: project-id, milestone-id: milestone-id }))))
    (milestone (unwrap! (map-get? milestones { project-id: project-id, milestone-id: milestone-id }) ERR-MILESTONE-NOT-FOUND))
  )
    ;; Check if all tasks are completed
    (if (is-all-tasks-completed project-id milestone-id task-count)
        (begin
          ;; Update milestone status to completed
          (map-set milestones
            { project-id: project-id, milestone-id: milestone-id }
            (merge milestone { status: STATUS-COMPLETED })
          )
          (ok true)
        )
        (ok false)
    )
  )

  (define-private (is-all-tasks-completed (project-id uint) (milestone-id uint) (count uint))
    (is-eq 
      (fold 
        (count-incomplete-tasks project-id milestone-id) 
        u0 
        (generate-task-ids count)
      )
      u0
    )
  )

  (define-private (count-incomplete-tasks (project-id uint) (milestone-id uint) (task-id uint) (acc uint))
    (let (
      (task-status (get status (default-to 
                                { status: u0 } 
                                (map-get? tasks { project-id: project-id, milestone-id: milestone-id, task-id: task-id }))))
    )
      (if (or (is-eq task-status STATUS-COMPLETED) (is-eq task-status STATUS-CANCELLED))
        acc
        (+ acc u1))
    )
  )
)

;; Helper to check and update project status when all milestones are complete
(define-public (check-and-update-project-status (project-id uint))
  (let (
    (milestone-count (get count (default-to { count: u0 } (map-get? project-milestone-count { project-id: project-id }))))
    (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
  )
    ;; Check if all milestones are completed
    (if (is-all-milestones-completed project-id milestone-count)
        (begin
          ;; Update project status to completed
          (map-set projects
            { project-id: project-id }
            (merge project { status: STATUS-COMPLETED })
          )
          (ok true)
        )
        (ok false)
    )
  )

  (define-private (is-all-milestones-completed (project-id uint) (count uint))
    (is-eq 
      (fold 
        (count-incomplete-milestones project-id) 
        u0 
        (generate-milestone-ids count)
      )
      u0
    )
  )

  (define-private (count-incomplete-milestones (project-id uint) (milestone-id uint) (acc uint))
    (let (
      (milestone-status (get status (default-to 
                                    { status: u0 } 
                                    (map-get? milestones { project-id: project-id, milestone-id: milestone-id }))))
    )
      (if (or (is-eq milestone-status STATUS-COMPLETED) (is-eq milestone-status STATUS-CANCELLED))
        acc
        (+ acc u1))
    )
  )
)

;; Add a communication entry
(define-public (add-communication (project-id uint) (message (string-utf8 1000)) (context-type (string-ascii 20)) (context-id uint))
  (let (
    (comm-count-data (default-to { count: u0 } (map-get? project-comm-count { project-id: project-id })))
    (comm-count (get count comm-count-data))
    (new-comm-id (+ comm-count u1))
  )
    ;; Ensure project exists
    (asserts! (is-some (map-get? projects { project-id: project-id })) ERR-PROJECT-NOT-FOUND)
    
    ;; Check authorization - any team member can add communication
    (asserts! (is-some (map-get? team-members { project-id: project-id, member: tx-sender })) ERR-NOT-AUTHORIZED)
    
    ;; Validate context type
    (asserts! 
      (or 
        (is-eq context-type "project")
        (is-eq context-type "milestone")
        (is-eq context-type "task")
      ) 
      ERR-INVALID-STATUS
    )
    
    ;; Store communication entry
    (map-set communications
      { project-id: project-id, comm-id: new-comm-id }
      {