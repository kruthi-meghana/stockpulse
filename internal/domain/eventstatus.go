type EventStatus string

const (
    StatusPending EventStatus = "pending"
    StatusDone    EventStatus = "done"
    StatusFailed  EventStatus = "failed"
)