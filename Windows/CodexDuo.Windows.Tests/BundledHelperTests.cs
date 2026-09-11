using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using CodexDuo.Windows.Core;

namespace CodexDuo.Windows.Tests;

public sealed class BundledHelperTests : IDisposable
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "Codex Duo helper tests", Guid.NewGuid().ToString("N"));

    private string PrepareHelper()
    {
        var fixture = Path.Combine(AppContext.BaseDirectory, "Fixtures", "Helper");
        var helpers = Path.Combine(directory, "Helpers");
        Directory.CreateDirectory(helpers);
        var archive = Path.Combine(fixture, "codex-auth-Windows-X64.zip");
        using var manifest = JsonDocument.Parse(File.ReadAllText(Path.Combine(fixture, "manifest.json")));
        using var stream = File.OpenRead(archive);
        Assert.Equal(manifest.RootElement.GetProperty("archiveSha256").GetString(), Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant());
        ZipFile.ExtractToDirectory(archive, helpers);
        File.Copy(Path.Combine(fixture, "manifest.json"), Path.Combine(helpers, "manifest.json"));
        return Path.Combine(helpers, "codex-auth.exe");
    }

    [Fact]
    public async Task NativeHelper_RunsFromPackagedLocationWithSpaces()
    {
        var executable = PrepareHelper();
        var command = new ToolLocator(directory).FindCodexAuth();
        Assert.NotNull(command);
        Assert.Equal(executable, command.FileName);
        Assert.Empty(command.PrefixArguments);
        var result = await new ProcessCommandRunner().RunAsync(command, ["--version"], TimeSpan.FromSeconds(10));
        Assert.True(result.Succeeded, result.StandardError);
        Assert.Equal("codex-auth 0.3.0-alpha.10", result.StandardOutput.Trim());
    }

    [Fact]
    public void MissingOrDamagedBundle_NeverUsesExternalInstallation()
    {
        Assert.Null(new ToolLocator(directory).FindCodexAuth());
        var executable = PrepareHelper();
        File.WriteAllText(executable, "damaged");
        Assert.Null(new ToolLocator(directory, allowExternalFallback: true).FindCodexAuth());
        File.Delete(executable);
        Assert.Null(new ToolLocator(directory, allowExternalFallback: true).FindCodexAuth());
    }

    [Theory]
    [InlineData("version", "0.0.0")]
    [InlineData("architecture", "arm64")]
    public void UnexpectedManifest_IsRejected(string field, string value)
    {
        PrepareHelper();
        var path = Path.Combine(directory, "Helpers", "manifest.json");
        var manifest = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(path))!;
        manifest[field] = value;
        File.WriteAllText(path, JsonSerializer.Serialize(manifest));
        Assert.Null(new ToolLocator(directory).FindCodexAuth());
    }

    [Fact]
    public async Task AccountOperations_SelectBundledExecutable()
    {
        var executable = PrepareHelper();
        var runner = new RecordingRunner();
        var service = new CodexAuthService(runner, new ToolLocator(directory));
        Assert.True((await service.RefreshAsync()).Succeeded);
        Assert.True((await service.SetAliasAsync("person@example.com", " alias ")).Succeeded);
        Assert.True((await service.RemoveAccountAsync("person@example.com")).Succeeded);
        Assert.True((await service.SwitchAsync("key", "person@example.com")).Succeeded);
        Assert.Equal(4, runner.Commands.Count);
        Assert.All(runner.Commands, command => { Assert.Equal(executable, command.FileName); Assert.Empty(command.PrefixArguments); });
    }

    [Fact]
    public async Task MissingHelper_ReportsReinstallation()
    {
        var result = await new CodexAuthService(locator: new ToolLocator(directory)).RefreshAsync();
        Assert.Equal(127, result.ExitCode);
        Assert.Contains("reinstall", result.StandardError, StringComparison.Ordinal);
        Assert.DoesNotContain("npm", result.StandardError, StringComparison.Ordinal);
    }

    [Fact]
    public void LoginScript_QuotesHelperAndFindsOfficialDesktopCli()
    {
        var script = CodexAuthService.BuildLoginScript(ToolCommand.Executable(@"C:\Duo's tools\codex-auth.exe"));
        Assert.Contains("& 'C:\\Duo''s tools\\codex-auth.exe' 'login'", script, StringComparison.Ordinal);
        Assert.Contains("OpenAI.Codex_2p2nqsd0c76g0", script, StringComparison.Ordinal);
        Assert.Contains("app\\resources", script, StringComparison.Ordinal);
        Assert.Contains("exit $loginExitCode", script, StringComparison.Ordinal);
        Assert.DoesNotContain("npm install", script, StringComparison.Ordinal);
    }

    private sealed class RecordingRunner : ICommandRunner
    {
        public List<ToolCommand> Commands { get; } = [];
        public Task<CommandResult> RunAsync(ToolCommand command, IEnumerable<string> arguments, TimeSpan timeout, bool captureOutput = true, CancellationToken cancellationToken = default)
        {
            Commands.Add(command);
            return Task.FromResult(new CommandResult(0,
                arguments.First() == "switch" ? """{"schema_version":1,"command":"switch","switched_to":{"account_key":"key"}}""" : string.Empty,
                string.Empty));
        }
    }

    public void Dispose()
    {
        if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }
}
