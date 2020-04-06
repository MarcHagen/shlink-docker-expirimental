<?php

declare(strict_types=1);

namespace Shlinkio\Shlink;

use Laminas\Stdlib\ArrayUtils\MergeReplaceKey;
use Monolog\Handler\StreamHandler;
use Monolog\Logger;

use function explode;
use function Functional\contains;
use function Shlinkio\Shlink\Common\env;

$helper = new class {
    private const DB_DRIVERS_MAP = [
        'mysql' => 'pdo_mysql',
        'maria' => 'pdo_mysql',
        'postgres' => 'pdo_pgsql',
    ];
    private const DB_PORTS_MAP = [
        'mysql' => '3306',
        'maria' => '3306',
        'postgres' => '5432',
    ];

    public function getDbConfig(): array
    {
        $driver = env('DB_DRIVER');
        if ($driver === null || $driver === 'sqlite') {
            return [
                'driver' => 'pdo_sqlite',
                'path' => 'data/database.sqlite',
            ];
        }

        $driverOptions = ! contains(['maria', 'mysql'], $driver) ? [] : [
            // 1002 => \PDO::MYSQL_ATTR_INIT_COMMAND
            1003 => 'SET NAMES utf8',
            1004 => \PDO::MYSQL_ATTR_USE_BUFFERED_QUERY,
        ];
        return [
            'driver' => self::DB_DRIVERS_MAP[$driver],
            'dbname' => env('DB_NAME', 'shlink'),
            'user' => env('DB_USER'),
            'password' => env('DB_PASSWORD'),
            'host' => env('DB_HOST'),
            'port' => env('DB_PORT', self::DB_PORTS_MAP[$driver]),
            'driverOptions' => $driverOptions,
        ];
    }

    public function getNotFoundRedirectsConfig(): array
    {
        return [
            'invalid_short_url' => env('INVALID_SHORT_URL_REDIRECT_TO'),
            'regular_404' => env('REGULAR_404_REDIRECT_TO'),
            'base_url' => env('BASE_URL_REDIRECT_TO'),
        ];
    }

    public function getVisitsWebhooks(): array
    {
        $webhooks = env('VISITS_WEBHOOKS');
        return $webhooks === null ? [] : explode(',', $webhooks);
    }

    public function getRedisConfig(): ?array
    {
        $redisServers = env('REDIS_SERVERS');
        return $redisServers === null ? null : ['servers' => $redisServers];
    }
};

return [

    'config_cache_enabled' => false,

    'app_options' => [
        'disable_track_param' => env('DISABLE_TRACK_PARAM'),
    ],

    'delete_short_urls' => [
        'check_visits_threshold' => true,
        'visits_threshold' => (int) env('DELETE_SHORT_URL_THRESHOLD', 15),
    ],

    'entity_manager' => [
        'connection' => $helper->getDbConfig(),
    ],

    'url_shortener' => [
        'domain' => [
            'schema' => env('SHORT_DOMAIN_SCHEMA', 'http'),
            'hostname' => env('SHORT_DOMAIN_HOST', ''),
        ],
        'validate_url' => (bool) env('VALIDATE_URLS', false),
        'visits_webhooks' => $helper->getVisitsWebhooks(),
    ],

    'not_found_redirects' => $helper->getNotFoundRedirectsConfig(),

    'logger' => [
        'Shlink' => [
            'handlers' => [
                'shlink_handler' => [
                    'name' => StreamHandler::class,
                    'params' => [
                        'level' => Logger::INFO,
                        'stream' => 'php://stdout',
                    ],
                ],
            ],
        ],
    ],

    'dependencies' => [
        'aliases' => env('REDIS_SERVERS') === null ? [] : [
            'lock_store' => 'redis_lock_store',
        ],
    ],

    'cache' => [
        'redis' => $helper->getRedisConfig(),
    ],

    'router' => [
        'base_path' => env('BASE_PATH', ''),
    ],

    'mezzio-swoole' => [
        'swoole-http-server' => [
            'options' => [
                'worker_num' => (int) env('WEB_WORKER_NUM', 16),
                'task_worker_num' => (int) env('TASK_WORKER_NUM', 16),
            ],
        ],
    ],

    /**
     * If using a second proxy (clien > apache > traefik > container) the X-Real-IP is the IP of the 1ste proxy
     * X-Forwarded-For is then preferred because it contains the client IP: client, proxy1, (proxy2, ...)
     */
    'ip_address_resolution' => [
        'headers_to_inspect' => new MergeReplaceKey([
            'Forwarded',
            'X-Forwarded-For',
            'X-Forwarded',
            'X-Cluster-Client-Ip',
            'Client-Ip',
        ]),
    ],
];
