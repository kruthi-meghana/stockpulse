type Event struct {
    ID         int64       // your database's ID
    WebhookID  string      // Shopify's ID for this message (to catch duplicates)
    Payload    []byte      // the raw JSON, exactly as received
    Status     EventStatus // pending, done, or failed
    ReceivedAt time.Time   // when it arrived
}