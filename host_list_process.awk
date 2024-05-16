# @todo fix parsing ssh_config file without empty lines between `Host` declarations

function join(array, start, end, sep, result, i) {
  # https://www.gnu.org/software/gawk/manual/html_node/Join-Function.html
  if (sep == "")
    sep = " "
  else if (sep == SUBSEP) # magic value
    sep = ""
  result = array[start]
  for (i = start + 1; i <= end; i++)
    result = result sep array[i]
  return result
}

function parse_line(line) {
  n = split(line, line_array, " ")

  key = line_array[1]
  value = join(line_array, 2, n)

  return key "#-#" value
}

function contains_star(str) {
    return index(str, "*") > 0
}

function starts_or_ends_with_star(str) {
    start_char = substr(str, 1, 1)
    end_char = substr(str, length(str), 1)

    return start_char == "*" || end_char == "*"
}

BEGIN {
  IGNORECASE = 1
  FS="\n"
  RS=""

  host_list = ""
}
{
  match_directive = ""

  # Use spaces to ensure the column command maintains the correct number of columns.
  #   - desc_formated

  host_name = ""
  alias = ""
  desc = ""
  desc_formated = " "

  for (line_num = 1; line_num <= NF; ++line_num) {
    line = parse_line($line_num)

    split(line, tmp, "#-#")

    key = tolower(tmp[1])
    value = tmp[2]

    if (key == "match") { match_directive = value }
    if (key == "host") { aliases = value }
    if (key == "hostname") { host_name = value }
    if (key == "#_desc") { desc = value }
  }

  split(aliases, alias_list, " ")
  for (i in alias_list) {
    alias = alias_list[i]

    if (!host_name && alias ) {
      host_name = alias
    }

    if (desc) {
      desc_formated = sprintf("[\033[00;34m%s\033[0m]", desc)
    }

    if ((host_name && !starts_or_ends_with_star(host_name)) && (alias && !starts_or_ends_with_star(alias)) && !match_directive) {
      host = sprintf("%s|->|%s|%s\n", alias, host_name, desc_formated)
      host_list = host_list host
    }
  }
}
END {
  print host_list
}
