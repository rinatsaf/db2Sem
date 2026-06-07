# Neo4j Demo

## Запуск

```bash
docker compose up -d
```

Открыть в браузере:
http://localhost:7474

Подключение через CLI
```bash
docker exec -it neo4j-demo cypher-shell -u neo4j -p password
```

Логин:
neo4j
Пароль:
password

## Импорт данных
```cypher
LOAD CSV WITH HEADERS FROM
'https://raw.githubusercontent.com/Mario-cartoon/ArticleBD/main/Category.csv'
AS line FIELDTERMINATOR ','
MERGE (category:Category {categoryID: line.title})
  ON CREATE SET category.title = line.title;

LOAD CSV WITH HEADERS FROM
'https://raw.githubusercontent.com/Mario-cartoon/ArticleBD/main/Articles.csv'
AS line FIELDTERMINATOR ','
MERGE (article:Article {articleID: line.title});

LOAD CSV WITH HEADERS FROM
'https://raw.githubusercontent.com/Mario-cartoon/ArticleBD/main/Reader.csv'
AS line FIELDTERMINATOR ','
MERGE (reader:Reader {readerID: line.name})
  ON CREATE SET reader.nickname = line.nickname,reader.email = line.email;

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/Mario-cartoon/ArticleBD/main/Category_articles.csv' AS line
MATCH (category:Category {categoryID: line.title_category})
MATCH (article:Article {articleID: line.title_article})
CREATE (article)-[:IS_IN]->(category);

LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/Mario-cartoon/ArticleBD/main/read_articles.csv' AS line
MATCH (reader:Reader {readerID: line.name})
MATCH (article:Article {articleID: line.title_article})
CREATE (reader)-[:READ]->(article);
```

## Отображение всех узлов и связей
```cypher
MATCH (n)
OPTIONAL MATCH (n)-[r]-()
RETURN n, r;
```