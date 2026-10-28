using Na.Application.Services;
using Na.Infrastructure;
using Na.Worker;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddNaDatabase();
builder.Services.AddNaExternalApis(builder.Configuration);
builder.Services.AddSingleton<OutboxRelayService>();
builder.Services.AddSingleton<TimerSweepService>();

builder.Services.AddOptions<WorkerOptions>().Bind(builder.Configuration.GetSection(WorkerOptions.SectionName));

builder.Services.AddHostedService<OutboxRelayWorker>();
builder.Services.AddHostedService<TimerSweepWorker>();

builder.Build().Run();
