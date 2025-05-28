# This function returns 0 (true) if this script is being ran under WSL
function is_wsl {
  grep -qi 'microsoft' /proc/version
  return $?
}