pub const Config = struct {
    version: []const u8,
    server: ServerConfig,
    agents: AgentConfig,
    deployment: DeploymentConfig,
    logging: LoggingConfig,
    pub fn createDefaultConfig() Config {
        return .{
            .version = "1.0.0",
            .server = .{
                .host = "localhost",
                .port = 8080,
                .auth = .{
                    .auth_type = "token",
                    .token = "",
                },
                .tls = .{
                    .enabled = false,
                    .cert_path = "",
                    .key_path = "",
                },
            },
            .agents = .{
                .connection = .{
                    .retry_attempts = 3,
                    .retry_delay = 5,
                    .timeout = 30,
                },
                .paths = .{
                    .base_deploy = "/opt/zbs/deployments",
                    .temp = "/opt/zbs/temp",
                },
                .health_check_interval = 60,
            },
            .deployment = .{ .default_strategy = "all_at_once", .backup = .{
                .enabled = true,
                .keep_versions = 3,
                .path = "/opt/zbs/backups",
            }, .patterns = .{
                .include = &[_][]const u8{"**/*"},
                .exclude = &[_][]const u8{ ".git", "node_modules", "*.tmp" },
            } },
            .logging = .{
                .level = "info",
                .file = "/var/log/zbs/zbs.log",
                .max_size = 10485760,
                .max_files = 5,
            },
        };
    }
};

const ServerConfig = struct {
    host: []const u8,
    port: u16,
    auth: AuthConfig,
    tls: TlsConfig,
};

const AuthConfig = struct {
    auth_type: []const u8,
    token: []const u8,
};

const TlsConfig = struct {
    enabled: bool,
    cert_path: []const u8,
    key_path: []const u8,
};

const AgentConfig = struct {
    connection: ConnectionConfig,
    paths: PathsConfig,
    health_check_interval: u32,
};

const ConnectionConfig = struct {
    retry_attempts: u8,
    retry_delay: u8,
    timeout: u32,
};

const PathsConfig = struct {
    base_deploy: []const u8,
    temp: []const u8,
};

const DeploymentConfig = struct {
    default_strategy: []const u8,
    backup: BackupConfig,
    patterns: PatternsConfig,
};

const BackupConfig = struct {
    enabled: bool,
    keep_versions: u8,
    path: []const u8,
};

const PatternsConfig = struct {
    include: []const []const u8,
    exclude: []const []const u8,
};

const LoggingConfig = struct { level: []const u8, file: []const u8, max_size: u64, max_files: u8 };
