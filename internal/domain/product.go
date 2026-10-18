
type Product struct {
    SKU               string // product code; matches LineItem.SKU from Shopify
    Name              string // e.g. "Marine Collagen"
    Stock             int    // how many you have right now
    LowStockThreshold int    // alert when stock falls below this
}

func (p Product) IsLowStock() bool {
    return p.Stock < p.LowStockThreshold
}