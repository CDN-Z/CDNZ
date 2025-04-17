```note
/etc/nginx/
├── nginx.conf                  # Main configuration file
├── conf.d/                     # Module configurations
│   ├── ssl.conf                # SSL settings
│   ├── security-headers.conf   # Security headers
│   └── cache.conf              # Caching rules
├── sites-enabled/              # Active site configurations
├── lua/                        # Lua scripts directory
│   ├── cdn/                    # CDN-specific Lua modules
│   │   ├── auth.lua            # Authentication logic
│   │   ├── cache_control.lua   # Cache control logic
│   │   └── edge_logic.lua      # Edge processing logic
│   └── lib/                    # Shared Lua libraries
└── stream.d/                   # TCP/UDP configurations (if needed)
```