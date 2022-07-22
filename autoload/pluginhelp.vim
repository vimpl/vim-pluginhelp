let s:mode_order = {'n':0, 'i':1, 'c':2, 'v':3, 's':4, 'o':5, 't':6, 'l':7}

" This requires hupfdule/log.vim
silent! let s:log = log#getLogger(expand('<sfile>:t'))


""
" Show a short help regarding the current mappings and settings.
"
" {plugin_spec} must be a dictionary containing all the information
" necessary to fill the help window. All of them are optional, but if none
" are given the result help window will be empty.
"
"   'help_topic': The topic that must be given to ':h' to display the
"                 corresponding vimhelp file.
"                 Used to display a line that refers to that help file.
"   'mappings':   A list of mappings to display. See below for details of
"                 that list.
"   'settings':   A list of settings to display. See below for details of
"                 that list
"
" The 'mappings' and 'settings' are lists with a dictionary per mapping /
" setting.
" Each entry in 'mappings' must contain the following keys:
"
"   'plugmap':  The name of the <Plug>-Mapping (rhs of a mapping) to display.
"   'desc':     A short description of that mapping
"
" Each entry in 'settings' must contain the following keys:
"
"   'setting':  The name of the setting to display.
"   'desc':     A short description of that setting
"
" Example:
"   let plugin_spec = {
"     \ 'help_topic': 'push',
"     \ 'mappings':  [
"     \    {'plugmap': '<Plug>(PushCursorBACK)', 'desc': 'Push cursor back WORD-wise'},
"     \    {'plugmap': '<Plug>(PushCursorBack)', 'desc': 'Push cursor back word-wise'},
"     \  ],
"     \ 'settings':  [
"     \    {'setting': 'g:push_no_default_mappings', 'desc': 'Whether to avoid setting default mappings'},
"     \  ],
"     \ }
function! pluginhelp#show(plugin_spec) abort
  if has_key(a:plugin_spec, 'mappings')
    let l:mappings = s:parse_mappings(a:plugin_spec['mappings'])
  else
    let l:mappings = []
  endif

  " Prepare the help content
  let content = []

  " Refer to main help topic
  if has_key(a:plugin_spec, 'help_topic')
    call extend(content, ['See `:help '.a:plugin_spec['help_topic'].'` for more details and the hardcoded defaults.'])
  endif

  " Show mappings
  if has_key(a:plugin_spec, 'mappings') && a:plugin_spec['mappings'] !=# []
    " calculate the max length of all mappings
    let l:mode_max_length = 0
    let l:lhs_max_length = 0
    let l:rhs_prefix_max_length = 0
    let l:rhs_max_length = 0
    for m in l:mappings
      let l:mode_max_length = max([l:mode_max_length, len(m['mode'])])
      let l:lhs_max_length = max([l:lhs_max_length, len(m['lhs'])])
      let l:rhs_prefix_max_length = max([l:rhs_prefix_max_length, len(m['rhs-prefix'])])
      let l:rhs_max_length = max([l:rhs_max_length, len(m['rhs'])])
    endfor

    call extend(content, ['', 'MAPPINGS', ''])
    for m in l:mappings
      let l:mode = s:rpad(m['mode'], l:mode_max_length)
      if m['lhs'] =~# '^\s*$'
        let l:lhs = s:rpad(' ', l:lhs_max_length)
      else
        let l:lhs = s:rpad('*' . m['lhs'] . '*', l:lhs_max_length + 2)
      endif
      let l:rhs_prefix = s:lpad(m['rhs-prefix'], l:rhs_prefix_max_length)
      let l:rhs = s:rpad(m['rhs'], l:rhs_max_length)
      call add(content, '  ' . l:mode . '  ' . l:lhs . '  ' . l:rhs_prefix . l:rhs . ' » ' . m['desc'])
    endfor
  endif

  " Show settings
  if has_key(a:plugin_spec, 'settings') && a:plugin_spec['settings'] !=# []
    let l:settings = s:parse_settings(a:plugin_spec['settings'])

    " calculate the max length of all settings
    let l:setting_max_length = 0
    let l:value_max_length = 0
    for s in l:settings
      let l:setting_max_length = max([l:setting_max_length, len(s['setting'])])
      let l:value_max_length = max([l:value_max_length, len(s['value'])])
    endfor

    call extend(content, ['', 'SETTINGS', ''])
    for s in l:settings
      let l:setting = s:rpad('*' . s['setting'] . '*', l:setting_max_length + 2)
      let l:value   = s:rpad(s['value'],    l:value_max_length)
      call add(content, '  ' . l:setting . ' = ' . l:value . ' » ' . s['desc'])
    endfor
  endif

  " Open the dialog
  if exists('g:quickui_version')
    let opts = {'syntax': 'help'}
    call quickui#textbox#open(content, opts)
  else
    call s:show_in_window(content)
  endif
endfunction


""
" Parse the settings of plugin_spec.
"
" It reads the actual current value of the setting and returns alist of
" dictionaries with the setting information of those settings.
"
" Each entry in the returned list will be a dictionary with the following fields:
"
"  'setting': The name of the setting
"  'value':   The value of the setting
"  'desc':    The short description of the setting (taken from the plugin_spec)
"
" @param {settings} The value of the 'settings' key in the plugin_spec.
"                   Must be a list of dictionaries. See @link {pluginhelp#show()}
"                   for details of that dictionaries.
" @returns A list of dictionaries with the settings information
function! s:parse_settings(settings) abort
  let l:settings = []

  for s in a:settings
    if exists(s['setting'])
      execute "let l:value = " . s['setting']
    else
      execute "let l:value = '<unset>'"
    endif

    call add(l:settings, {'setting': s['setting'], 'value': l:value, 'desc': s['desc']})
  endfor

  return l:settings
endfunction


""
" Parse the mappings of plugin_spec.
"
" It reads the actually mapped values, filters it to the mappings defined
" in the plugin_spec and returns a list of dictionaries with the mapping
" information of those mappings.
"
" Each entry in the returned list will be a dictionary with the following fields:
"
"  'mode':        The mode of the mapping
"  'lhs':         The lhs of the mapping
"  'rhs-prefix':  The prefix characters of the mapping (*, &, @)
"  'rhs':         The rhs of the mapping
"  'desc':        The short description of the mapping (taken from the plugin_spec)
"
" @param {mappings} The value of the 'mappings' key in the plugin_spec.
"                   Must be a list of dictionaries. See @link
"                   {pluginhelp#show()} for details of that dictionaries.
" @returns A list of dictionaries with the mappings information
function! s:parse_mappings(mappings) abort
  " List all mappings
  let l:a = @a
  redir @a
  let @a=''
  " list all mappings
  silent map
  silent map!
  silent tmap
  redir END
  " a list of all mappings, one string per mapping
  let l:all_mappings = split(@a, "\n")
  " filter out all empty lines
  call filter(l:all_mappings, "v:val !~# '^\s\*$'")

  " Try to filter out most the non-matching mappings as early as possible
  " There will be a finer grained filtering later on
  if len(l:all_mappings) > 300
    let l:common_substring= s:get_common_substring(map(copy(a:mappings), 'v:val["plugmap"]'))
    silent! s:log.debug('Trying to reduce ' . len(l:all_mappings) . ' possible mappings by filtering by common substring: ' . l:common_substring)
    let l:all_mappings = filter(l:all_mappings, 'v:val =~# "\\V' . l:common_substring .'"')
    silent! s:log.debug('Reduced possible mappings to ' . len(l:all_mappings))
  endif

  " convert to a list of lists; each mapping string is split by whitespace
  for i in range(len(l:all_mappings))
    let s:split= matchlist(l:all_mappings[i], '\(..\)\s\+\(\S\+\)\s\+\([*&@]*\)\s*\(.*\)')
    if s:split ==# []
      " If we cannot process this mapping, emit a log message
      silent! call s:log.warn('Unrecognized mapping: ' . s:all_mappings[i])
      continue
    endif
    let l:all_mappings[i] = {'mode':s:split[1], 'lhs':s:split[2], 'rhs-prefix':s:split[3], 'rhs':s:split[4]}
  endfor
  let @a = l:a

  " Try to speed up the next loops by reducing l:all_mappings to mappings
  " mappings that contain a substring that is common to all plugin-mappings
  if len(l:all_mappings) * len(a:mappings) > 300
    if len(l:common_substring) >= 3
      silent! s:log.debug('Trying to reduce ' . len(l:all_mappings) . ' possible mappings even further by filtering by common substring in rhs: ' . l:common_substring)
      let l:all_mappings = filter(l:all_mappings, 'v:val["rhs"] =~# "\\V' . l:common_substring .'"')
      silent! s:log.debug('Reduced possible mappings to ' . len(l:all_mappings))
    endif
  endif

  " Filter the mappings to reduce to only the interesting ones
  let l:mappings = []
  for my_mapping in a:mappings
    let l:mapping_found = v:false
    for mapping in l:all_mappings
      if mapping['rhs'] ==# my_mapping['plugmap']
        " Replace an empty string with the actual modes
        if mapping['mode'] =~# '^\s*$'
          let mapping['mode'] = 'nvso'
        endif
        " Replace an 'x' mark with 'vs' (for visual and select mode)
        let mapping['mode'] = substitute(mapping['mode'], 'x', 'vs', '')
        " Replace an exclamation mark with the actual modes
        let mapping['mode'] = substitute(mapping['mode'], '!', 'ic', '')
        " Remove all remaining spaces
        let mapping['mode'] = substitute(mapping['mode'], '\s\+', '', '')
        let l:print_map = {'mode': mapping['mode'], 'lhs': mapping['lhs'], 'rhs-prefix': mapping['rhs-prefix'], 'rhs': mapping['rhs'], 'desc': my_mapping['desc']}
        call add(l:mappings, l:print_map)
        let l:mapping_found = v:true
      endif
    endfor
    " Create an entry for unmapped mappings
    if !mapping_found
      let l:print_map = {'mode': '', 'lhs': '', 'rhs-prefix': '', 'rhs': my_mapping['plugmap'], 'desc': my_mapping['desc']}
      call add(l:mappings, l:print_map)
    endif
  endfor

  call s:merge_equal_mappings(l:mappings)

  return l:mappings
endfunction


""
" Find a substring common to all {string}.
"
" This is a naïve approach that only compares the /start/ of the strings.
" If there are common strings, but the first characters differ, an empty
" string will be returned.
" But usually this is enough as that would catch typical <Plug>-mappings
" that all start with the same phrase, like <Plug>(Push…
"
" @param {strings} a list of strings to get the common substring for
" @returns the substring common to all {strings}. May be an empty string if
"          not all {strings} have such a common string
function! s:get_common_substring(strings) abort
  if empty(a:strings)
    return ''
  endif

  let l:common = ''

  " get the length of the shortest string
  let l:length = min(map(copy(a:strings), 'len(v:val)'))

  for i in range(l:length)
    let l:ch = strcharpart(a:strings[0], i, 1)
    for s in a:strings
      if strcharpart(s, i, 1) !=# l:ch
        return l:common
      endif
    endfor
    let l:common .= l:ch
  endfor

  return l:common
endfunction


""
" Merge equal mappings for different modes into one entry.
"
" If the 'lhs', 'rhs' and the 'rhs-prefix' of two entries are equal they can be
" merged into a single entry.
" This is necessary as we have to execute different queries to find
" mappings for normal and insert mode.
"
" The changes are made directly to the given list {mappings}. This method
" does not return it.
"
" @param {mappings} a list of dictionaries with one entry for each mapping
"                   as returned by @link s:parse_mappings().
function! s:merge_equal_mappings(mappings) abort
  " Dictionary to remember the entries to identify duplicates
  let l:map_dict = {}

  for mapping in a:mappings
    if has_key(l:map_dict, mapping['rhs-prefix'].mapping['rhs'])
      " If the same mapping is bound to different modes, then merge the
      " modes here
      let l:duplicate = l:map_dict[mapping['rhs-prefix'].mapping['rhs']]
      let l:modes = l:duplicate['mode'] . mapping['mode']
      let l:duplicate['mode'] = l:modes
      call remove(a:mappings, index(a:mappings, mapping))
    else
      let l:map_dict[mapping['rhs-prefix'].mapping['rhs']] = mapping
    endif
  endfor

  let l:mapped_modes = {}
  for m in a:mappings
    let l:modes = split(m['mode'], '\zs')
    let l:modes = filter(l:modes, 'v:val isnot " "')
    let l:modes = uniq(l:modes)
    let l:modes = sort(l:modes, function("s:compare_modes"))
    for mode in l:modes
      let l:mapped_modes[mode] = v:true
    endfor
    "let m['mode'] = join(l:modes, '')
    let m['mode'] = l:modes
  endfor

  " Now align the mode characters
  for m in a:mappings
    let l:modes = [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ']
    for l:mode in m['mode']
      let l:idx = s:mode_order[l:mode]
      let l:modes[l:idx] = l:mode
    endfor

    " Remove mode columns that aren't used in any mapping
    for [mode, idx] in items(s:mode_order)
      if !get(l:mapped_modes, mode, v:false)
        let l:modes[idx] = 'O'  " these will be removed later
      endif
    endfor
    let m['mode'] = join(l:modes, '')
    let m['mode'] = substitute(m['mode'], '\CO', '', 'g')
  endfor
endfunction


""
" Compare mode characters (for sorting).
"
" Mode characters are sorted in the following order:
"
"   nicvsotl
"
" @returns - a positive integer if 'm1' is considered "after" 'm2'
"          - a negative integer if 'm1' is considered "before" 'm2'
"          - 0 if both are considered equal
function! s:compare_modes(m1, m2) abort
  return s:mode_order[a:m1] - s:mode_order[a:m2]
endfunction


""
" Compare two lists with mapping information.
"
" Both lists must have exactly 3 items:
"
"   1. mode
"   2. {lhs}
"   3. {rhs}
"
" Comparison will compare from the last to the first item. That means first the
" {rhs} is compared, if they are equal, the {lhs} is compared and only if
" that is equal the mode will be compared.
"
" @returns - a positive integer if 'm1' is considered "after" 'm2'
"          - a negative integer if 'm1' is considered "before" 'm2'
"          - 0 if both are considered equal
function! s:compare_mappings(m1, m2) abort
  let l:result = s:compare(a:m1[2], a:m2[2])
  if l:result !=# 0
    return l:result
  endif

  let l:result = s:compare(a:m1[1], a:m2[1])
  if l:result !=# 0
    return l:result
  endif

  return s:compare(a:m1[0], a:m2[0])
endfunction


""
" Compare two values.
"
" @return -1 if the first argument is considered smaller
"          1 if the first argument is considered  larger
"          0 if both arguments are considered equal
function! s:compare(v1, v2) abort
  if a:v1 < a:v2
    return -1
  elseif a:v1 > a:v2
    return 1
  else
    return 0
  endif
endfunction


""
" Display the given lines of text in a new split window.
"
" The window will be resized to display the whole text.
" The windows will get settings for a temporary buffer and can be closed
" with either 'q' or 'gq'.
function! s:show_in_window(content) abort
  if bufexists('pushhelp')
    " if the help buffer already exists, jump to it
    let l:winnr = bufwinnr('pushhelp')
    execute l:winnr . "wincmd w"
  else
    " otherwise create the help buffer
    execute len(a:content) + 1 . 'new'
    call append(0, a:content)
    setlocal syntax=help nomodifiable nomodified buftype=nofile bufhidden=wipe nowrap nonumber
    file pushhelp
    nnoremap <buffer> q  :close<cr>
    nnoremap <buffer> gq :close<cr>
  endif
endfunction


""
" Right-pad the given 'string' to the given 'length'.
function! s:rpad(string, length) abort
  return a:string . repeat(' ', a:length - len(a:string))
endfunction


""
" Left-pad the given 'string' to the given 'length'.
function! s:lpad(string, length) abort
  return repeat(' ', a:length - len(a:string)) . a:string
endfunction

