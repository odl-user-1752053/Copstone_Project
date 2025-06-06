#!/bin/bash

# push_to_github.sh - Script per automatizzare il push su GitHub
# Usage: ./push_to_github.sh [file_path] [commit_message] [branch_name]

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Funzione per mostrare l'help
show_help() {
    echo "Usage: $0 [OPTIONS] [FILE_PATH]"
    echo ""
    echo "OPTIONS:"
    echo "  -f, --file FILE_PATH     File specifico da committare (opzionale)"
    echo "  -m, --message MESSAGE    Messaggio di commit (default: timestamp)"
    echo "  -b, --branch BRANCH      Branch su cui pushare (default: main)"
    echo "  -a, --all               Aggiungi tutti i file modificati"
    echo "  -h, --help              Mostra questo help"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Push tutti i file modificati"
    echo "  $0 -f app.html                       # Push solo app.html"
    echo "  $0 -m \"Fix calculator bug\"           # Push con messaggio custom"
    echo "  $0 -b develop -f script.js           # Push su branch develop"
}

# Valori di default
FILE_PATH=""
COMMIT_MESSAGE=""
BRANCH_NAME="main"
ADD_ALL=false

# Parse degli argomenti
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            FILE_PATH="$2"
            shift 2
            ;;
        -m|--message)
            COMMIT_MESSAGE="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        -a|--all)
            ADD_ALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$FILE_PATH" ]]; then
                FILE_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Verifica se siamo in una repository Git
if [ ! -d ".git" ]; then
    print_error "Non sei in una repository Git. Inizializza prima con 'git init'"
    exit 1
fi

# Verifica se ci sono remote configurati
if ! git remote -v | grep -q origin; then
    print_warning "Nessun remote 'origin' configurato."
    read -p "Vuoi aggiungere un remote? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Inserisci l'URL del repository GitHub: " repo_url
        git remote add origin "$repo_url"
        print_success "Remote origin aggiunto: $repo_url"
    else
        print_error "Impossibile continuare senza un remote configurato"
        exit 1
    fi
fi

# Controlla lo status della repository
print_info "Controllo status della repository..."
git_status=$(git status --porcelain)

if [ -z "$git_status" ]; then
    print_warning "Nessuna modifica da committare"
    exit 0
fi

# Mostra i file modificati
print_info "File modificati:"
git status --short

# Stage dei file
if [ "$ADD_ALL" = true ]; then
    print_info "Aggiungendo tutti i file modificati..."
    git add .
elif [ -n "$FILE_PATH" ]; then
    if [ -f "$FILE_PATH" ]; then
        print_info "Aggiungendo file: $FILE_PATH"
        git add "$FILE_PATH"
    else
        print_error "File non trovato: $FILE_PATH"
        exit 1
    fi
else
    print_info "Aggiungendo tutti i file modificati (default)..."
    git add .
fi

# Verifica che ci siano file staged
staged_files=$(git diff --cached --name-only)
if [ -z "$staged_files" ]; then
    print_warning "Nessun file staged per il commit"
    exit 0
fi

print_info "File staged per il commit:"
echo "$staged_files"

# Genera messaggio di commit se non fornito
if [ -z "$COMMIT_MESSAGE" ]; then
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    COMMIT_MESSAGE="Update files - $timestamp"
    print_info "Usando messaggio di commit automatico: $COMMIT_MESSAGE"
fi

# Conferma prima del commit
echo
read -p "Procedere con il commit e push? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Operazione annullata"
    exit 0
fi

# Commit
print_info "Eseguendo commit..."
if git commit -m "$COMMIT_MESSAGE"; then
    print_success "Commit eseguito con successo"
else
    print_error "Errore durante il commit"
    exit 1
fi

# Verifica se il branch esiste sul remote
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    print_info "Branch $BRANCH_NAME esiste sul remote"
else
    print_warning "Branch $BRANCH_NAME non esiste sul remote. Verrà creato."
fi

# Push
print_info "Eseguendo push su branch: $BRANCH_NAME"
if git push origin "$BRANCH_NAME"; then
    print_success "Push completato con successo!"
    
    # Mostra informazioni sul commit
    echo
    print_info "Dettagli del commit:"
    git log --oneline -1
    
    # Mostra URL del repository se possibile
    repo_url=$(git remote get-url origin)
    if [[ $repo_url == *"github.com"* ]]; then
        # Converte SSH URL in HTTPS per il browser
        if [[ $repo_url == git@github.com:* ]]; then
            repo_url="https://github.com/${repo_url#git@github.com:}"
            repo_url="${repo_url%.git}"
        fi
        print_info "Repository: $repo_url"
    fi
    
else
    print_error "Errore durante il push"
    
    # Suggerimenti per problemi comuni
    echo
    print_info "Possibili soluzioni:"
    echo "1. Verifica le credenziali GitHub"
    echo "2. Controlla se hai i permessi di push"
    echo "3. Prova: git pull origin $BRANCH_NAME --rebase"
    echo "4. Verifica la connessione internet"
    
    exit 1
fi

# Cleanup opzionale
read -p "Vuoi vedere lo status finale? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Status finale:"
    git status
fi

print_success "Script completato!"
