(defn usage []
  (print "usage: pkg command [args]")
  (print "       pkg help [command]")
  (print "")
  (print "commands:")
  (print "  help         show general or command help")
  (print "  list         list registry packages")
  (print "  search       search registry packages")
  (print "  installed    list installed packages")
  (print "  show         show package metadata")
  (print "  info         show installed package details")
  (print "  install      install a package")
  (print "  reinstall    reinstall current package version")
  (print "  remove       remove a package")
  (print "  upgrade      upgrade one package or --all")
  (print "  self-upgrade upgrade pkg itself")
  (print "  cleanup      remove build state, optionally cache")
  (print "  audit        report integrity issues")
  (print "  version      show pkg source metadata")
  (print "  doctor       print layout and path diagnostics"))

(defn command-help [topic fail-fn]
  (case topic
    nil (usage)
    "help" (do
             (print "usage: pkg help [command]")
             (print "")
             (print "Show general help or help for a single command."))
    "list" (do
             (print "usage: pkg list")
             (print "")
             (print "List package names and current registry versions."))
    "search" (do
               (print "usage: pkg search term")
               (print "")
               (print "Search package names and notes."))
    "installed" (do
                  (print "usage: pkg installed")
                  (print "")
                  (print "List installed packages with version, kind, and source."))
    "show" (do
             (print "usage: pkg show package")
             (print "")
             (print "Show registry metadata for a package."))
    "info" (do
             (print "usage: pkg info package")
             (print "")
             (print "Show installed package state from the manifest."))
    "install" (do
                (print "usage: pkg install package")
                (print "       pkg install --dry-run package")
                (print "")
                (print "Fetch, build, and install a package."))
    "reinstall" (do
                  (print "usage: pkg reinstall package")
                  (print "")
                  (print "Remove the current installed version, then install it again."))
    "remove" (do
               (print "usage: pkg remove package")
               (print "       pkg remove --dry-run package")
               (print "")
               (print "Remove the current registry version of a package."))
    "upgrade" (do
                (print "usage: pkg upgrade package")
                (print "       pkg upgrade --dry-run package")
                (print "       pkg upgrade --all")
                (print "")
                (print "Upgrade one installed package to the current registry version,")
                (print "or upgrade all installed packages that are behind."))
    "self-upgrade" (do
                     (print "usage: pkg self-upgrade")
                     (print "")
                     (print "Refresh pkg itself from the configured bootstrap source."))
    "cleanup" (do
                (print "usage: pkg cleanup [--cache]")
                (print "")
                (print "Remove build state. With --cache, also remove cached downloads."))
    "audit" (do
              (print "usage: pkg audit")
              (print "")
              (print "Report packages missing required integrity data."))
    "version" (do
                (print "usage: pkg version")
                (print "")
                (print "Show installed pkg bootstrap source and revision."))
    "doctor" (do
               (print "usage: pkg doctor")
               (print "")
               (print "Show pkg paths and basic environment diagnostics."))
    (fail-fn (string "unknown help topic: " topic))))
