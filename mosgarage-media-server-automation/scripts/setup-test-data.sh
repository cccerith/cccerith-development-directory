#!/bin/bash
# ===============================================
# MOCK DATA SETUP FOR TESTING
# ===============================================
# Creates realistic test media files, configurations,
# and sample data for comprehensive testing
# ===============================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MEDIA_ROOT="${MEDIA_ROOT:-/mnt/artie}"
TEST_DATA_SIZE="${TEST_DATA_SIZE:-small}"  # small, medium, large

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_info() {
    log "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log "${RED}[ERROR]${NC} $*"
}

print_header() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " MOCK DATA SETUP FOR TESTING"
    echo "==============================================="
    echo -e "${NC}"
    echo "Media Root: $MEDIA_ROOT"
    echo "Data Size: $TEST_DATA_SIZE"
    echo ""
}

create_directory_structure() {
    log_info "Creating test directory structure..."
    
    # Main media directories
    mkdir -p "$MEDIA_ROOT"/{movies,tv,music,books,downloads}
    
    # Download subdirectories
    mkdir -p "$MEDIA_ROOT/downloads"/{complete,incomplete,watch,blackhole}
    mkdir -p "$MEDIA_ROOT/downloads"/{sonarr,radarr,transmission,nzbget}
    
    # Media subdirectories for organization
    mkdir -p "$MEDIA_ROOT/movies"/{action,comedy,drama,horror,sci-fi}
    mkdir -p "$MEDIA_ROOT/tv"/{drama,comedy,documentary,anime}
    mkdir -p "$MEDIA_ROOT/music"/{rock,pop,classical,electronic}
    mkdir -p "$MEDIA_ROOT/books"/{fiction,non-fiction,technical}
    
    # Set proper ownership
    chown -R 1001:1001 "$MEDIA_ROOT" 2>/dev/null || sudo chown -R 1001:1001 "$MEDIA_ROOT" || true
    chmod -R 755 "$MEDIA_ROOT"
    
    log_success "Directory structure created"
}

create_sample_movies() {
    log_info "Creating sample movie files..."
    
    local movies=(
        "action/The.Matrix.1999/The.Matrix.1999.1080p.BluRay.x264.mkv"
        "action/Blade.Runner.2049.2017/Blade.Runner.2049.2017.4K.HDR.mkv"
        "comedy/The.Grand.Budapest.Hotel.2014/The.Grand.Budapest.Hotel.2014.1080p.mkv"
        "drama/The.Shawshank.Redemption.1994/The.Shawshank.Redemption.1994.1080p.mkv"
        "horror/The.Thing.1982/The.Thing.1982.1080p.BluRay.mkv"
        "sci-fi/Interstellar.2014/Interstellar.2014.IMAX.1080p.mkv"
    )
    
    for movie in "${movies[@]}"; do
        local movie_path="$MEDIA_ROOT/movies/$movie"
        mkdir -p "$(dirname "$movie_path")"
        
        # Create appropriately sized mock files based on test data size
        case "$TEST_DATA_SIZE" in
            small)
                echo "Mock movie file: $(basename "$movie")" > "$movie_path"
                ;;
            medium)
                dd if=/dev/zero of="$movie_path" bs=1M count=100 2>/dev/null
                ;;
            large)
                dd if=/dev/zero of="$movie_path" bs=1M count=1000 2>/dev/null
                ;;
        esac
        
        # Create subtitle files
        echo "1\n00:00:00,000 --> 00:00:05,000\nSample subtitle for $(basename "$movie" .mkv)" > "${movie_path%.mkv}.srt"
        
        # Create NFO files (metadata)
        cat > "${movie_path%.mkv}.nfo" << EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<movie>
    <title>$(basename "$movie" | sed 's/\./ /g' | sed 's/ [0-9].*//g')</title>
    <year>$(echo "$movie" | grep -o '[0-9]\{4\}' | head -1)</year>
    <genre>$(dirname "$movie" | sed 's|.*/||g' | sed 's/.*/\u&/')</genre>
    <plot>Sample plot for testing purposes</plot>
    <runtime>120</runtime>
    <rating>8.5</rating>
</movie>
EOF
    done
    
    log_success "Created $(echo "${movies[@]}" | wc -w) sample movies"
}

create_sample_tv_shows() {
    log_info "Creating sample TV show files..."
    
    local shows=(
        "drama/Breaking.Bad"
        "comedy/The.Office.US"
        "documentary/Planet.Earth"
        "anime/Attack.on.Titan"
    )
    
    for show in "${shows[@]}"; do
        local show_name=$(basename "$show")
        local show_dir="$MEDIA_ROOT/tv/$show_name"
        
        # Create multiple seasons
        for season in {1..3}; do
            local season_dir="$show_dir/Season $(printf "%02d" $season)"
            mkdir -p "$season_dir"
            
            # Create episodes for each season
            local episode_count=10
            [[ $season -eq 1 ]] && episode_count=13
            
            for episode in $(seq 1 $episode_count); do
                local episode_file="$season_dir/${show_name}.S$(printf "%02d" $season)E$(printf "%02d" $episode).1080p.WEB-DL.mkv"
                
                case "$TEST_DATA_SIZE" in
                    small)
                        echo "Mock TV episode: $(basename "$episode_file")" > "$episode_file"
                        ;;
                    medium)
                        dd if=/dev/zero of="$episode_file" bs=1M count=50 2>/dev/null
                        ;;
                    large)
                        dd if=/dev/zero of="$episode_file" bs=1M count=500 2>/dev/null
                        ;;
                esac
                
                # Create subtitle files
                echo "1\n00:00:00,000 --> 00:00:05,000\nSample subtitle for episode" > "${episode_file%.mkv}.srt"
            done
            
            # Create season NFO
            cat > "$season_dir/tvshow.nfo" << EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<tvshow>
    <title>$(echo "$show_name" | sed 's/\./ /g')</title>
    <season>$season</season>
    <genre>$(dirname "$show" | sed 's|.*/||g' | sed 's/.*/\u&/')</genre>
    <plot>Sample TV show for testing purposes</plot>
    <network>Test Network</network>
    <status>Continuing</status>
</tvshow>
EOF
        done
    done
    
    log_success "Created sample TV shows with episodes"
}

create_sample_downloads() {
    log_info "Creating sample download files..."
    
    # Create files in download directories
    local download_dirs=(
        "complete"
        "incomplete"
        "sonarr"
        "radarr"
    )
    
    for dir in "${download_dirs[@]}"; do
        mkdir -p "$MEDIA_ROOT/downloads/$dir"
        
        # Create sample download files
        case "$dir" in
            complete)
                echo "Sample completed torrent" > "$MEDIA_ROOT/downloads/$dir/Sample.Movie.2024.1080p.mkv"
                echo "Sample completed TV episode" > "$MEDIA_ROOT/downloads/$dir/Sample.Show.S01E01.mkv"
                ;;
            incomplete)
                echo "Partial download in progress" > "$MEDIA_ROOT/downloads/$dir/Sample.Download.part"
                ;;
            sonarr)
                echo "TV episode processed by Sonarr" > "$MEDIA_ROOT/downloads/$dir/TV.Show.S01E05.mkv"
                ;;
            radarr)
                echo "Movie processed by Radarr" > "$MEDIA_ROOT/downloads/$dir/Movie.2024.1080p.mkv"
                ;;
        esac
    done
    
    # Create torrent files
    mkdir -p "$MEDIA_ROOT/downloads/watch"
    echo "mock torrent data" > "$MEDIA_ROOT/downloads/watch/sample.torrent"
    
    log_success "Created sample download files"
}

create_sample_configurations() {
    log_info "Creating sample service configurations..."
    
    local config_dir="$PROJECT_DIR/docker/configs-test"
    mkdir -p "$config_dir"
    
    # Create Sonarr test config
    mkdir -p "$config_dir/sonarr"
    cat > "$config_dir/sonarr/config.xml" << 'EOF'
<Config>
  <Port>8989</Port>
  <SslPort>9898</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey>test-sonarr-api-key-123456789012345678901234</ApiKey>
  <AuthenticationMethod>None</AuthenticationMethod>
  <Branch>main</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
</Config>
EOF
    
    # Create Radarr test config
    mkdir -p "$config_dir/radarr"
    cat > "$config_dir/radarr/config.xml" << 'EOF'
<Config>
  <Port>7878</Port>
  <SslPort>6878</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey>test-radarr-api-key-123456789012345678901234</ApiKey>
  <AuthenticationMethod>None</AuthenticationMethod>
  <Branch>master</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
</Config>
EOF
    
    # Create Prowlarr test config
    mkdir -p "$config_dir/prowlarr"
    cat > "$config_dir/prowlarr/config.xml" << 'EOF'
<Config>
  <Port>9696</Port>
  <SslPort>6969</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey>test-prowlarr-api-key-123456789012345678901234</ApiKey>
  <AuthenticationMethod>None</AuthenticationMethod>
  <Branch>master</Branch>
  <LogLevel>info</LogLevel>
  <SslCertPath></SslCertPath>
  <SslCertPassword></SslCertPassword>
  <UrlBase></UrlBase>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
</Config>
EOF
    
    # Create Bazarr test config
    mkdir -p "$config_dir/bazarr"
    cat > "$config_dir/bazarr/config.yaml" << 'EOF'
general:
  ip: 0.0.0.0
  port: 6767
  base_url: ""
  path_mappings: []
  debug: false
  branch: master
  auto_update: true
  single_language: false
  minimum_score: 90
  use_scenename: true
  use_postprocessing: false
  postprocessing_cmd: ""
  use_sonarr: true
  use_radarr: true

auth:
  type: none
  username: ""
  password: ""
  apikey: test-bazarr-api-key-123456789012345678901234

sonarr:
  ip: sonarr-test
  port: 8989
  base_url: ""
  ssl: false
  apikey: test-sonarr-api-key-123456789012345678901234
  full_update: Daily
  only_monitored: false

radarr:
  ip: radarr-test
  port: 7878
  base_url: ""
  ssl: false
  apikey: test-radarr-api-key-123456789012345678901234
  full_update: Daily
  only_monitored: false
EOF
    
    # Set proper ownership for configs
    chown -R 1001:1001 "$config_dir" 2>/dev/null || sudo chown -R 1001:1001 "$config_dir" || true
    
    log_success "Created sample service configurations"
}

create_test_database_files() {
    log_info "Creating test database files..."
    
    local config_dir="$PROJECT_DIR/docker/configs-test"
    
    # Create SQLite databases for services that use them
    if command -v sqlite3 >/dev/null 2>&1; then
        # Sonarr database
        mkdir -p "$config_dir/sonarr"
        sqlite3 "$config_dir/sonarr/sonarr.db" << 'EOF'
CREATE TABLE Series (Id INTEGER PRIMARY KEY, Title TEXT, Path TEXT);
INSERT INTO Series VALUES (1, 'Test Show', '/data/tv/Test Show');
EOF
        
        # Radarr database  
        mkdir -p "$config_dir/radarr"
        sqlite3 "$config_dir/radarr/radarr.db" << 'EOF'
CREATE TABLE Movies (Id INTEGER PRIMARY KEY, Title TEXT, Path TEXT);
INSERT INTO Movies VALUES (1, 'Test Movie', '/data/movies/Test Movie');
EOF
        
        log_success "Created test database files"
    else
        log_warning "sqlite3 not available, skipping database creation"
    fi
}

generate_sample_logs() {
    log_info "Generating sample log files..."
    
    local logs_dir="$PROJECT_DIR/logs"
    mkdir -p "$logs_dir"
    
    # Create sample application logs
    cat > "$logs_dir/sample-sonarr.log" << 'EOF'
2024-01-15 10:00:00.000|Info|Bootstrap|Starting Sonarr
2024-01-15 10:00:01.000|Info|Database|Database migration completed
2024-01-15 10:00:02.000|Info|WebHost|Listening on port 8989
2024-01-15 10:00:03.000|Info|SeriesService|Loading series from database
2024-01-15 10:00:04.000|Info|IndexerFactory|Loaded 5 indexers
2024-01-15 10:00:05.000|Info|TaskManager|Starting scheduled tasks
EOF
    
    cat > "$logs_dir/sample-radarr.log" << 'EOF'
2024-01-15 10:00:00.000|Info|Bootstrap|Starting Radarr
2024-01-15 10:00:01.000|Info|Database|Database migration completed
2024-01-15 10:00:02.000|Info|WebHost|Listening on port 7878
2024-01-15 10:00:03.000|Info|MovieService|Loading movies from database
2024-01-15 10:00:04.000|Info|IndexerFactory|Loaded 5 indexers
2024-01-15 10:00:05.000|Info|TaskManager|Starting scheduled tasks
EOF
    
    log_success "Generated sample log files"
}

validate_test_data() {
    log_info "Validating created test data..."
    
    local validation_passed=true
    
    # Check directory structure
    local required_dirs=(
        "$MEDIA_ROOT/movies"
        "$MEDIA_ROOT/tv"
        "$MEDIA_ROOT/downloads/complete"
        "$MEDIA_ROOT/downloads/incomplete"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Missing directory: $dir"
            validation_passed=false
        fi
    done
    
    # Check sample files exist
    if [[ ! -f "$MEDIA_ROOT/movies/action/The.Matrix.1999/The.Matrix.1999.1080p.BluRay.x264.mkv" ]]; then
        log_error "Sample movie file missing"
        validation_passed=false
    fi
    
    # Check configuration files
    local config_dir="$PROJECT_DIR/docker/configs-test"
    if [[ ! -f "$config_dir/sonarr/config.xml" ]]; then
        log_error "Sonarr test config missing"
        validation_passed=false
    fi
    
    if $validation_passed; then
        log_success "All test data validated successfully"
        return 0
    else
        log_error "Test data validation failed"
        return 1
    fi
}

show_summary() {
    echo -e "${GREEN}"
    echo "==============================================="
    echo " MOCK DATA SETUP COMPLETED"
    echo "==============================================="
    echo -e "${NC}"
    
    echo "📊 Created Test Data:"
    echo "  • Media Root: $MEDIA_ROOT"
    echo "  • Sample Movies: $(find "$MEDIA_ROOT/movies" -name "*.mkv" 2>/dev/null | wc -l)"
    echo "  • Sample TV Episodes: $(find "$MEDIA_ROOT/tv" -name "*.mkv" 2>/dev/null | wc -l)"
    echo "  • Download Files: $(find "$MEDIA_ROOT/downloads" -type f 2>/dev/null | wc -l)"
    echo "  • Configuration Files: $(find "$PROJECT_DIR/docker/configs-test" -name "*.xml" -o -name "*.yaml" 2>/dev/null | wc -l)"
    
    local total_size=$(du -sh "$MEDIA_ROOT" 2>/dev/null | cut -f1 || echo "Unknown")
    echo "  • Total Size: $total_size"
    
    echo ""
    echo "🎯 Test Environment:"
    echo "  • Data Size Profile: $TEST_DATA_SIZE"
    echo "  • Ready for automated testing"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Run test suite: ./scripts/test-suite.sh"
    echo "  2. Start services: docker-compose -f docker-compose.test.yml --env-file .env.test up -d"
    echo "  3. Access testing interfaces on alternate ports"
}

main() {
    print_header
    
    log_info "Starting mock data setup for testing..."
    
    # Create all test data
    create_directory_structure
    create_sample_movies
    create_sample_tv_shows
    create_sample_downloads
    create_sample_configurations
    create_test_database_files
    generate_sample_logs
    
    # Validate everything was created correctly
    if validate_test_data; then
        show_summary
        log_success "Mock data setup completed successfully"
        exit 0
    else
        log_error "Mock data setup completed with errors"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Mock Data Setup for Testing"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h           Show this help message"
        echo "  --size small|medium|large   Set test data size (default: small)"
        echo "  --media-root PATH    Set media root directory (default: /mnt/artie)"
        echo "  --clean              Clean existing test data"
        echo ""
        exit 0
        ;;
    --size)
        TEST_DATA_SIZE="$2"
        shift 2
        main "$@"
        ;;
    --media-root)
        MEDIA_ROOT="$2"
        shift 2
        main "$@"
        ;;
    --clean)
        log_info "Cleaning existing test data..."
        rm -rf "$MEDIA_ROOT" 2>/dev/null || sudo rm -rf "$MEDIA_ROOT" || true
        rm -rf "$PROJECT_DIR/docker/configs-test" 2>/dev/null || true
        log_success "Test data cleaned"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac