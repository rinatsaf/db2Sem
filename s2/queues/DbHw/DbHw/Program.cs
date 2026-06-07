using Npgsql;
using System;
using System.Threading.Tasks;

class Producer
{
    static async Task Main()
    {
        var connString = Environment.GetEnvironmentVariable("ConnectionStrings__Default")
                         ?? "Host=db;Username=postgres;Password=rk091011;Database=task_db";

        using var conn = new NpgsqlConnection(connString);
        await conn.OpenAsync();

        var rnd = new Random();

        while (true)
        {
            using var tx = await conn.BeginTransactionAsync();
            try
            {
                // Генерация приоритета: 20% критических, 80% обычных
                int priority = rnd.NextDouble() < 0.2 ? 100 : 0;
                string payload = $"Task at {DateTime.Now:HH:mm:ss.fff}";

                // Фиктивная бизнес-логика
                bool businessCheck = rnd.NextDouble() > 0.05; // 95% успешных вставок
                if (!businessCheck)
                    throw new Exception("Business logic failed");

                var cmd = new NpgsqlCommand(
                    "INSERT INTO tasks (payload, priority) VALUES (@p, @prio)", conn, tx);
                cmd.Parameters.AddWithValue("p", payload);
                cmd.Parameters.AddWithValue("prio", priority);
                await cmd.ExecuteNonQueryAsync();

                await tx.CommitAsync();
            }
            catch
            {
                await tx.RollbackAsync();
            }

            await Task.Delay(5); // ~200 insertions/sec per producer
        }
    }
}