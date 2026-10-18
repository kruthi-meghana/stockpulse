type Order struct {
    Id      int64
    Name    string
    LineItems []LineItem
	CustomerId int64
}