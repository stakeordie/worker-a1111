from webui import initialize
import modules.interrogate
import modules.sd_models

initialize.initialize()
interrogator = modules.interrogate.InterrogateModels("interrogate")
interrogator.load()
interrogator.categories()
sd_models.load('/2_1.ckpt')
