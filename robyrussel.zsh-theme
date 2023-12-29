# Sets color variable such as $fg, $bg, $color and $reset_color
autoload -U colors && colors

# Expand variables and commands in PROMPT variables
setopt prompt_subst

# Prompt function theming defaults
ZSH_THEME_GIT_PROMPT_PREFIX="git:("   # Beginning of the git prompt, before the branch name
ZSH_THEME_GIT_PROMPT_SUFFIX=")"       # End of the git prompt
ZSH_THEME_GIT_PROMPT_DIRTY="*"        # Text to display if the branch is dirty
ZSH_THEME_GIT_PROMPT_CLEAN=""         # Text to display if the branch is clean
ZSH_THEME_RUBY_PROMPT_PREFIX="("
ZSH_THEME_RUBY_PROMPT_SUFFIX=")"

# The git prompt's git commands are read-only and should not interfere with
# other processes. This environment variable is equivalent to running with `git
# --no-optional-locks`, but falls back gracefully for older versions of git.
# See git(1) for and git-status(1) for a description of that flag.
#
# We wrap in a local function instead of exporting the variable directly in
# order to avoid interfering with manually-run git commands by the user.
function __git_prompt_git() {
    GIT_OPTIONAL_LOCKS=0 command git "$@"
}

function git_prompt_info() {
    # If we are on a folder not tracked by git, get out.
    # Otherwise, check for hide-info at global and local repository level
    if ! __git_prompt_git rev-parse --git-dir &> /dev/null \
        || [[ "$(__git_prompt_git config --get robbyrussell.hide-info 2>/dev/null)" == 1 ]]; then
        return 0
    fi

    local ref
    ref=$(__git_prompt_git symbolic-ref --short HEAD 2> /dev/null) \
        || ref=$(__git_prompt_git describe --tags --exact-match HEAD 2> /dev/null) \
        || ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null) \
        || return 0

    # Use global ZSH_THEME_GIT_SHOW_UPSTREAM=1 for including upstream remote info
    local upstream
    if (( ${+ZSH_THEME_GIT_SHOW_UPSTREAM} )); then
        upstream=$(__git_prompt_git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null) \
            && upstream=" -> ${upstream}"
    fi

    echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${ref:gs/%/%%}${upstream:gs/%/%%}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}

# Checks if working tree is dirty
function parse_git_dirty() {
    local STATUS
    local -a FLAGS
    FLAGS=('--porcelain')
    if [[ "$(__git_prompt_git config --get robbyrussell.hide-dirty)" != "1" ]]; then
        if [[ "${DISABLE_UNTRACKED_FILES_DIRTY:-}" == "true" ]]; then
            FLAGS+='--untracked-files=no'
        fi
        case "${GIT_STATUS_IGNORE_SUBMODULES:-}" in
            git)
                # let git decide (this respects per-repo config in .gitmodules)
                ;;
            *)
                # if unset: ignore dirty submodules
                # other values are passed to --ignore-submodules
                FLAGS+="--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}"
                ;;
        esac
        STATUS=$(__git_prompt_git status ${FLAGS} 2> /dev/null | tail -n 1)
    fi
    if [[ -n $STATUS ]]; then
        echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
    else
        echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
    fi
}

# Outputs the name of the current branch
# Usage example: git pull origin $(git_current_branch)
# Using '--quiet' with 'symbolic-ref' will not cause a fatal error (128) if
# it's not a symbolic ref, but in a Git repo.
function git_current_branch() {
    local ref
    ref=$(__git_prompt_git symbolic-ref --quiet HEAD 2> /dev/null)
    local ret=$?
    if [[ $ret != 0 ]]; then
        [[ $ret == 128 ]] && return  # no git repo.
        ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null) || return
    fi
    echo ${ref#refs/heads/}
}

# Output the name of the root directory of the git repository
# Usage example: $(git_repo_name)
function git_repo_name() {
    local repo_path
    if repo_path="$(__git_prompt_git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$repo_path" ]]; then
        echo ${repo_path:t}
    fi
}

PROMPT="%(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}%1{✗%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
