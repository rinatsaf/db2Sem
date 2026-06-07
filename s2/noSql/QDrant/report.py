from qdrant_client import QdrantClient
from qdrant_client.models import *
from sentence_transformers import SentenceTransformer

client = QdrantClient(host="localhost", port=6333)
model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

## Подготовка данных

# Создайте коллекцию articles с векторами размерности 384.
# Вставьте 5-10 статей с полями:
# - title (заголовок)
# - content (содержание)
# - author (автор)
# - category (категория: "tech", "sport", "news")
# - published_at (дата публикации)
# - views (количество просмотров)
# - rating (рейтинг 0-5)

if client.collection_exists("articles"):
    client.delete_collection("articles")

client.create_collection(
    collection_name="articles",
    vectors_config=models.VectorParams(
        size=384,
        distance=models.Distance.COSINE
    )
)


articles = [
    {
        "title": "Почему бег - это от дьявола",
        "content": "Бег — один из самых ужасных видов спорта. В этой статье мы разберём технику бега, выбор обуви и план тренировок на первый месяц.",
        "author": "Бебрила Бебрилова",
        "category": "sport",
        "published_at": "2024-03-15T10:00:00Z",
        "views": 4520,
        "rating": 4.8
    },
    {
        "title": "Нейросети в 2030: почему нас всех заменят",
        "content": "Обзор современных архитектур нейросетей, прогнозы на будущее",
        "author": "Дядя Вася",
        "category": "tech",
        "published_at": "2024-02-20T14:30:00Z",
        "views": 8900,
        "rating": 4.9
    },
    {
        "title": "Чемпионат мира по спортивному выпиванию пива: итоги недели",
        "content": "Обзор ключевых матчей, статистика игроков и прогнозы на следующие туры.",
        "author": "Иван Козлов",
        "category": "sport",
        "published_at": "2024-04-01T18:00:00Z",
        "views": 3200,
        "rating": 4.2
    },
    {
        "title": "Кибербезопасность: как делать защиту максимально дырявой",
        "content": "Практические советы по поощрению SQL-инъекций, XSS-атак и уязвимостей в зависимостях. Примеры на Python и JavaScript.",
        "author": "Макс Максов",
        "category": "tech",
        "published_at": "2024-01-10T09:15:00Z",
        "views": 6700,
        "rating": 4.7
    },
    {
        "title": "Мировые новости: экономика и технологии",
        "content": "Еженедельный дайджест: СВО в Иране, новые ракеты по Киеву и прогнозы роста рынка шпрот в томатном соусе.",
        "author": "Мария Волкова",
        "category": "news",
        "published_at": "2024-03-28T12:00:00Z",
        "views": 2100,
        "rating": 3.9
    },
    {
        "title": "Йога и бег: как сочетать для лучшего результата",
        "content": "Почему растяжка после бега важна, и как после неё не откиснуть.",
        "author": "Ольга Смирнова",
        "category": "sport",
        "published_at": "2024-02-05T08:00:00Z",
        "views": 5100,
        "rating": 4.6
    },
    {
        "title": "Docker для начинающих: от установки до выхода в окно",
        "content": "Пошаговое руководство по контейнеризации приложений: Dockerfile, docker-compose, volumes и best practices.",
        "author": "Алексей Иванов",
        "category": "tech",
        "published_at": "2023-12-15T16:45:00Z",
        "views": 12400,
        "rating": 4.9
    },
    {
        "title": "Зимние виды спорта: как уходить в лес по Юнгеру",
        "content": "Горные лыжи, сноуборд, беговые лыжи: всё это бред. Руководство как освоить настоящий спорт, когда на дворе Февраль.",
        "author": "Сергей Лесников",
        "category": "sport",
        "published_at": "2023-11-20T11:30:00Z",
        "views": 1800,
        "rating": 4.1
    }
]

points = []
for idx, article in enumerate(articles, start=1):
    text_to_embed = f"{article['title']} {article['content']}"
    vector = model.encode(text_to_embed).tolist()
    
    points.append(
        models.PointStruct(
            id=idx,
            vector=vector,
            payload={
                "title": article["title"],
                "content": article["content"],
                "author": article["author"],
                "category": article["category"],
                "published_at": article["published_at"],
                "views": article["views"],
                "rating": article["rating"]
            }
        )
    )

client.upsert(collection_name="articles", points=points)
print(f"Загружено {len(points)} статей в коллекцию 'articles'")


# Поиск

# Выполните 4 запроса:
# - Простой поиск — найти 3 статьи, похожие на запрос "бег и спорт"
# - Поиск с фильтром по категории — найти статьи в категории "tech" с рейтингом >= 4.0
# - Поиск с диапазоном дат — найти статьи, опубликованные после "2024-01-01", с просмотрами > 1000
# - Сложный фильтр — найти статьи:
#     - Категория: "sport" ИЛИ "tech"
#     - Рейтинг >= 3.5
#     - Просмотры от 500 до 5000
#     - Отсортировать по релевантности (score)

query = "бег и спорт"
query_vector =  model.encode(query).tolist()

print("#1")
print(f"Простой поиск по запросу: '{query}'")

results = client.query_points(
    collection_name="articles",
    query=query_vector,
    limit=3
)

for hit in results.points:
    print(f"    > {hit.payload.get('title')} (score: {hit.score:.3f}, rating: {hit.payload.get('rating')})")

print("#2")
print(f"Tech-статьи с рейтингом >= 4.0:")

results = client.query_points(
    collection_name="articles",
    query=query_vector,
    query_filter=models.Filter(
        must=[
            FieldCondition(key="category", match=MatchValue(value="tech")),
            FieldCondition(key="rating", range=Range(gte=4.0))
        ]
    ),
    limit=5
)

for hit in results.points:
    print(f"    > {hit.payload['title']} (rating: {hit.payload['rating']}, views: {hit.payload['views']})")

print("#3")
print(f"Статьи с просмотрами > 10000:")

results = client.query_points(
    collection_name="articles",
    query=query_vector,
    query_filter=models.Filter(
        must=[
            FieldCondition(key="views", range=Range(gt=10000))
        ]
    ),
    limit=5
)

for hit in results.points:
    print(f"    > {hit.payload['title']} (published_at: {hit.payload['published_at'][:10]}, views: {hit.payload['views']})")

print("#4")
print(f"Сложный фильтр: (sport|tech) AND rating>=3.5 AND views[500-5000]")

results = client.query_points(
    collection_name="articles",
    query=query_vector,
    query_filter=models.Filter(
        must=[
            FieldCondition(key="category", match=MatchAny(any=["sport", "tech"])),
            FieldCondition(key="rating", range=Range(gte=3.5)),
            FieldCondition(key="views", range=Range(gte=500, lte=5000))
        ]
    ),
    limit=10,
    with_payload=True,
    with_vectors=False
)

for hit in results.points:
    p = hit.payload
    print(f"   > {p['title']} [{p['category']}] rating: {p['rating']} views:{p['views']} (score: {hit.score:.3f})")

## Индексы и оптимизация

# Создайте payload-индексы для полей:
# - category (keyword)
# - rating (float)
# - published_at (datetime)
# - views (integer)

client.create_payload_index(
    collection_name="articles",
    field_name="category",
    field_schema=models.PayloadSchemaType.KEYWORD
)
client.create_payload_index(
    collection_name="articles",
    field_name="rating",
    field_schema=models.PayloadSchemaType.FLOAT
)
client.create_payload_index(
    collection_name="articles",
    field_name="published_at",
    field_schema=models.PayloadSchemaType.DATETIME
)
client.create_payload_index(
    collection_name="articles",
    field_name="views",
    field_schema=models.PayloadSchemaType.INTEGER
)

# Замеров не будет, ибо данных мало, а генерировать большие лень. Поверьте на слово

# Задания для умных тоже не будет, потому что я не умный
# и вообще, оно задумывалось как опциональное для желающих лучше разобраться в теме, пусть там этого и не написано