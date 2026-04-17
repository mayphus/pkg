(def package
  @{
    :links [
      @{
        :name "hello-local"
        :path "hello-local"
      }
    ]
    :version "0.1.0"
    :source @{
      :path "examples"
      :type :link
    }
    :kind :cli
    :name "hello-local"
    :notes "Minimal local package for testing symlink install and removal."
  })
