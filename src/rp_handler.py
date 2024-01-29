import time

import runpod
import requests
from requests.adapters import HTTPAdapter, Retry
from datetime import date

LOCAL_URL = "http://127.0.0.1:3000/sdapi/v1"

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


def run_inference(inference_request):
    '''
    Run inference on a request.
    '''

    if(inference_request["type"] == "img2img"):
        async function getImage(url: string) {
            const response = await fetch(url);
            if (!response.ok) throw new Error("Failed to fetch image");
            const arrayBuffer = await response.arrayBuffer();
            const buffer = Buffer.from(arrayBuffer);
            return buffer.toString("base64");
        }
        const image = await getImage(inference_request["params"]["init_images"][0])
        inference_request["params"]["images"][0] = image
        response = automatic_session.post(url=f'{LOCAL_URL}/img2img',
                                      json=inference_request["params"], timeout=600)
    elif(inference_request["type"] == "extra-single-image"):
        response = automatic_session.post(url=f'{LOCAL_URL}/extra-single-image',
                                      json=inference_request["params"], timeout=600)
    else:
        response = automatic_session.post(url=f'{LOCAL_URL}/txt2img',
                                      json=inference_request["params"], timeout=600)

    # input_settings = inference_request["params"]
    # input_settings["image"] = ''
    # input_settings["images"] = ''
    # res_for_write = response.json()
    # res_for_write["image"] = ''
    # res_for_write['images'] = ''

    # today = str(date.today())
    # file_name = f'/runpod-volume/logs/{today}.json'
    # f = open(file_name, "a")
    # f.write("\n-------\n")
    # f.write(str(input_settings))
    # f.write("\nv^v^v^v^v^\n")
    # f.write(str(res_for_write))
    # f.write("\n-------\n")
    # f.close()

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
