using UnityEngine;
using UnityEngine.UI;
//hi
public class CameraController : MonoBehaviour
{
    public RawImage cameraDisplay;
    private WebCamTexture webcamTexture;

    void Start()
    {
        if (!Application.HasUserAuthorization(UserAuthorization.WebCam))
        {
            Application.RequestUserAuthorization(UserAuthorization.WebCam);
        }

        webcamTexture = new WebCamTexture(Screen.width, Screen.height, 30);
        webcamTexture.filterMode = FilterMode.Bilinear;
        webcamTexture.wrapMode = TextureWrapMode.Clamp;

        cameraDisplay.texture = webcamTexture;
        webcamTexture.Play();
    }

    void Update()
    {
        if (webcamTexture == null) return;

        // Fix rotation
        cameraDisplay.rectTransform.localEulerAngles =
            new Vector3(0, 0, -webcamTexture.videoRotationAngle);

        // Fix aspect ratio
        float ratio = (float)webcamTexture.width / webcamTexture.height;
        cameraDisplay.rectTransform.sizeDelta =
            new Vector2(Screen.height * ratio, Screen.height);
    }
}
