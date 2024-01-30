from webui import initialize
import modules.interrogate
from modules.sd_models import load_model

initialize.initialize()
interrogator = modules.interrogate.InterrogateModels("interrogate")
interrogator.load()
interrogator.categories()
