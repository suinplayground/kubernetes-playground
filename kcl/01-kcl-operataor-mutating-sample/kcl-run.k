import kcl_run
import filepath
import file

kcl_run.KCLRun {
    metadata.name = "pod-mutator"
    spec = {
        source = file.read(filepath.dir(file.current()) + "/pod-mutator/main.k")
    }
}
