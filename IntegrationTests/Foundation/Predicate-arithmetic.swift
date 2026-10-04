import Foundation

struct Product {
    var price: Double
    var count: Int
}

let affordable = #Predicate<Product> { product in
    product.price * Double(product.count) < 100.0
}
let negated = #Predicate<Product> { product in
    -product.price > -5.0
}
