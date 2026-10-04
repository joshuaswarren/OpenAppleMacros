import Foundation

struct Person {
    var name: String
    var age: Int
}

let adult = #Predicate<Person> { person in
    person.age >= 18
}
