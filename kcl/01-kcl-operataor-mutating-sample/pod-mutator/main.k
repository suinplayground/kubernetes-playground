import datetime

modify = lambda item {
    item.metadata.annotations["test/updated-by"] = "kcl-operator"
    item.metadata.annotations["test/updated-at"] = datetime.now()
    item
}

items = [modify(item) for item in option("items")]
