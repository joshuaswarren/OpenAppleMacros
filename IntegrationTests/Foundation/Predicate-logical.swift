import Foundation

struct Person {
    var name: String
    var age: Int
}

let teen = #Predicate<Person> { person in
    person.age >= 13 && person.age < 20
}
let youngOrNamed = #Predicate<Person> { person in
    person.age < 30 || person.name == "Josh"
}
let notTeen = #Predicate<Person> { person in
    !(person.age >= 13 && person.age < 20)
}
