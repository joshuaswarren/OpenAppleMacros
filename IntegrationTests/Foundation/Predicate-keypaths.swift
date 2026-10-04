import Foundation

struct Person {
    var name: String
    var address: Address?
}

struct Address {
    var city: String
}

let inDallas = #Predicate<Person> { person in
    person.address?.city == "Dallas"
}
let named = #Predicate<Person> {
    $0.name == "Josh"
}
