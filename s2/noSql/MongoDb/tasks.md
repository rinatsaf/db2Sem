# 1 задание
## Создание коллекции и добавление одной книги
    db.createCollection("books")

    db.books.insertOne({
    title: "Clean Code",
    genre: "programming",
    price: 45,
    available: true,
    tags: ["code", "best-practices", "software"],
    author: {
        name: "Robert C. Martin",
        country: "USA"
    }
    })

# 2 Задание
## Найти все книги в наличии
    db.books.find({
        available: true
    })

# 3 задание
## Добавить несколько документов
    db.books.insertMany([
    {
        title: "JavaScript: The Good Parts",
        genre: "programming",
        price: 30,
        available: true,
        tags: ["javascript", "web", "code"],
        author: {
        name: "Douglas Crockford",
        country: "USA"
        }
    },
    {
        title: "The Pragmatic Programmer",
        genre: "programming",
        price: 55,
        available: true,
        tags: ["software", "career", "code"],
        author: {
        name: "Andrew Hunt",
        country: "USA"
        }
    },
    {
        title: "Harry Potter and the Philosopher's Stone",
        genre: "fantasy",
        price: 25,
        available: false,
        tags: ["magic", "adventure", "fiction"],
        author: {
        name: "J. K. Rowling",
        country: "United Kingdom"
        }
    },
    {
        title: "1984",
        genre: "dystopian",
        price: 20,
        available: true,
        tags: ["classic", "politics", "fiction"],
        author: {
        name: "George Orwell",
        country: "United Kingdom"
        }
    },
    {
        title: "Design Patterns",
        genre: "programming",
        price: 60,
        available: false,
        tags: ["architecture", "oop", "patterns"],
        author: {
        name: "Erich Gamma",
        country: "Switzerland"
        }
    }
    ])
    
# 4 задание
## Сложный запрос (найдем книги у которых genre = programming, price>40, available = true)

    db.books.find(
    {
        genre: "programming",
        price: { $gt: 40 },
        available: true
    },
    {
        _id: 0,
        title: 1,
        price: 1
    }
    )