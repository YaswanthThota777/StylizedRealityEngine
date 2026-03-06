using UnityEngine;
using UnityEngine.UI;
//hi
public class CameraController : MonoBehaviour
{
    public RawImage cameraDisplay;
    public Material animeMaterial;

    private WebCamTexture webcamTexture;

    void Start()
    {
        Application.targetFrameRate = 60;

        if (!Application.HasUserAuthorization(UserAuthorization.WebCam))
        {
            Application.RequestUserAuthorization(UserAuthorization.WebCam);
        }

        // Use the highest-resolution camera available (back camera preferred on mobile)
        WebCamDevice[] devices = WebCamTexture.devices;
        string deviceName = devices.Length > 0 ? devices[0].name : null;
        for (int deviceIndex = 0; deviceIndex < devices.Length; deviceIndex++)
        {
            if (!devices[deviceIndex].isFrontFacing) { deviceName = devices[deviceIndex].name; break; }
        }

        webcamTexture = new WebCamTexture(deviceName, Screen.width, Screen.height, 60);
        webcamTexture.filterMode = FilterMode.Bilinear;
        webcamTexture.wrapMode = TextureWrapMode.Clamp;

        // Assign the webcam as the RawImage texture and apply the anime material
        cameraDisplay.texture = webcamTexture;
        if (animeMaterial != null)
            cameraDisplay.material = animeMaterial;

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
