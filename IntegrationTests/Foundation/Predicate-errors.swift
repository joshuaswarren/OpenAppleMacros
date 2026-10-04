import Foundation

struct Weird {
    func multiply(_ a: Int) -> Int { a }
}

let bad = #Predicate<Weird> { weird in
    weird.multiply(2) == 4
}
