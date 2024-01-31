import time
import base64
import runpod
import requests
import os
from requests.adapters import HTTPAdapter, Retry
from datetime import date

os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "max_split_size_mb:512"

LOCAL_URL = "http://0.0.0.0:3000/sdapi/v1"

automatic_session = requests.Session()
retries = Retry(total=10, backoff_factor=0.1, status_forcelist=[502, 503, 504])
automatic_session.mount('http://', HTTPAdapter(max_retries=retries))


# ---------------------------------------------------------------------------- #
#                              Automatic Functions                             #
# ---------------------------------------------------------------------------- #
def wait_for_service(url):
    '''
    Check if the service is ready to receive requests.
    '''
    while True:
        try:
            requests.get(url, timeout=120)
            return
        except requests.exceptions.RequestException:
            print("Service not ready yet. Retrying...")
        except Exception as err:
            print("Error: ", err)

        time.sleep(0.2)

def get_as_base64(url):

    return base64.b64encode(requests.get(url).content)

def run_inference(inference_request):
    '''
    Run inference on a request.
    '''

    if 'params' in inference_request:
        params = 'params'
    else:
        params = 'prompt'

    if(inference_request["type"] == "img2img"):
        if("http" in inference_request[params]["init_images"][0]):
            print("Pulling Image")
            image = get_as_base64(inference_request[params]["init_images"][0])
            image_string = image.decode('UTF-8')
            inference_request[params]["init_images"][0] = image_string
            print("Sending to API")
        response = automatic_session.post(url=f'{LOCAL_URL}/img2img',
                                      json=inference_request[params], timeout=600)
    elif(inference_request["type"] == "extra-single-image"):
        response = automatic_session.post(url=f'{LOCAL_URL}/extra-single-image',
                                      json=inference_request[params], timeout=600)
    else:
        response = automatic_session.post(url=f'{LOCAL_URL}/txt2img',
                                      json=inference_request[params], timeout=600)
    
    return response.json()

# ---------------------------------------------------------------------------- #
#                                RunPod Handler                                #
# ---------------------------------------------------------------------------- #
def handler(event):
    '''
    This is the handler function that will be called by the serverless.
    '''

    json = run_inference(event["input"])

    # return the output that you want to be returned like pre-signed URLs to output artifacts
    return json


if __name__ == "__main__":
    wait_for_service(url=f'{LOCAL_URL}/txt2img')

    print("WebUI API Service is ready. Starting RunPod...")

    runpod.serverless.start({"handler": handler})
