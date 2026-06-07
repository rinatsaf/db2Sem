using Npgsql;
using System;
using System.Threading.Tasks;

class Worker
{
    static async Task Main()
    {
        var connString = Environment.GetEnvironmentVariable("ConnectionStrings__Default")
                         ?? "Host=db;Username=postgres;Password=rk091011;Database=task_db";

        using var conn = new NpgsqlConnection(connString);
        await conn.OpenAsync();

        // Сигнал для пробуждения
        var tcs = new TaskCompletionSource<bool>();

        // Подписка на уведомления
        conn.Notification += (o, e) =>
        {
            Console.WriteLine($"[NOTIFY] New task: {e.Payload}");
            tcs.TrySetResult(true); // Пробуждаем цикл
        };

        using var listenCmd = new NpgsqlCommand("LISTEN task_added", conn);
        await listenCmd.ExecuteNonQueryAsync();

        // Фоновая задача для получения уведомлений
        _ = Task.Run(async () =>
        {
            while (true)
                await conn.WaitAsync();
        });

        Console.WriteLine("Worker started. Waiting for tasks...");

        while (true)
        {
            // Ждем уведомление или проверяем раз в 5 сек
            var task = await Task.WhenAny(tcs.Task, Task.Delay(5000));
            if (task == tcs.Task)
            {
                tcs = new TaskCompletionSource<bool>(); // Сбрасываем сигнал
            }
            else
            {
                Console.WriteLine("[Poll] Checking queue...");
            }

            // Забираем задачу
            var job = await FetchTask(conn);
            if (job == null) continue;

            bool success = await ProcessTask(job);
            await UpdateTask(conn, job.id, success);
        }

        // var connString = Environment.GetEnvironmentVariable("ConnectionStrings__Default")
        //                  ?? "Host=db;Username=postgres;Password=rk091011;Database=task_db";

        // using var conn = new NpgsqlConnection(connString);
        // await conn.OpenAsync();

        // // Подписка на уведомления
        // conn.Notification += (o, e) => Console.WriteLine($"New task: {e.Payload}");
        // using var listenCmd = new NpgsqlCommand("LISTEN task_added", conn);
        // await listenCmd.ExecuteNonQueryAsync();

        // while (true)
        // {
        //     var task = await FetchTask(conn);
        //     if (task == null)
        //     {
        //         await Task.Delay(1000); 
        //         continue;
        //     }

        //     bool success = await ProcessTask(task);

        //     await UpdateTask(conn, task.id, success);
        // }
    }

    static async Task<dynamic> FetchTask(NpgsqlConnection conn)
    {
        using var cmd = new NpgsqlCommand(@"
            UPDATE tasks
            SET status='Running'
            WHERE id = (
                SELECT id FROM tasks
                WHERE status='Ready' AND scheduled_at <= NOW()
                ORDER BY priority DESC, created_at ASC
                LIMIT 1
                FOR UPDATE SKIP LOCKED
            )
            RETURNING id, payload, priority, attempts", conn);

        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new
            {
                id = reader.GetInt32(0),
                payload = reader.GetString(1),
                priority = reader.GetInt32(2),
                attempts = reader.GetInt32(3)
            };
        }
        return null;
    }

    static async Task<bool> ProcessTask(dynamic task)
    {
        try
        {
            Console.WriteLine($"Processing task {task.id} (Priority {task.priority})");
            await Task.Delay(500); // эмуляция работы
            return new Random().NextDouble() > 0.1; // 10% fail rate
        }
        catch
        {
            return false;
        }
    }

    static async Task UpdateTask(NpgsqlConnection conn, int id, bool success)
    {
        if (success)
        {
            using var cmd = new NpgsqlCommand(
                "UPDATE tasks SET status='Completed' WHERE id=@id", conn);
            cmd.Parameters.AddWithValue("id", id);
            await cmd.ExecuteNonQueryAsync();
        }
        else
        {
            using var cmd = new NpgsqlCommand(@"
                UPDATE tasks
                SET status='Ready',
                    attempts = attempts + 1,
                    scheduled_at = NOW() + INTERVAL '5 minutes',
                    last_error = 'Processing failed'
                WHERE id=@id", conn);
            cmd.Parameters.AddWithValue("id", id);
            await cmd.ExecuteNonQueryAsync();
        }
    }
}