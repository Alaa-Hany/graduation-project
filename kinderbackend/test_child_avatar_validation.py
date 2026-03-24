from __future__ import annotations

import base64
import io

from PIL import Image


def _png_data_url(
    *, width: int = 4, height: int = 4, color: tuple[int, int, int] = (10, 20, 30)
) -> str:
    buffer = io.BytesIO()
    Image.new("RGB", (width, height), color=color).save(buffer, format="PNG")
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def test_child_create_accepts_known_avatar_asset_and_id(client, create_parent, auth_headers):
    parent = create_parent(email="avatar.parent@example.com", plan="PREMIUM")
    headers = auth_headers(parent)

    asset_response = client.post(
        "/children",
        json={
            "name": "Asset Kid",
            "picture_password": ["cat", "dog", "apple"],
            "age": 8,
            "avatar": "assets/images/avatars/girl1.png",
        },
        headers=headers,
    )
    assert asset_response.status_code == 200
    assert asset_response.json()["child"]["avatar"] == "assets/images/avatars/girl1.png"

    id_response = client.post(
        "/children",
        json={
            "name": "Id Kid",
            "picture_password": ["sun", "moon", "star"],
            "age": 9,
            "avatar": "boy1",
        },
        headers=headers,
    )
    assert id_response.status_code == 200
    assert id_response.json()["child"]["avatar"] == "boy1"


def test_child_create_accepts_valid_inline_avatar_image(client, create_parent, auth_headers):
    parent = create_parent(email="inline.avatar@example.com")
    headers = auth_headers(parent)
    avatar = _png_data_url()

    response = client.post(
        "/children",
        json={
            "name": "Inline Kid",
            "picture_password": ["cat", "dog", "apple"],
            "age": 8,
            "avatar": avatar,
        },
        headers=headers,
    )
    assert response.status_code == 200
    assert response.json()["child"]["avatar"].startswith("data:image/png;base64,")


def test_child_create_rejects_unsupported_avatar_reference(client, create_parent, auth_headers):
    parent = create_parent(email="bad.avatar.ref@example.com")
    headers = auth_headers(parent)

    response = client.post(
        "/children",
        json={
            "name": "Bad Ref",
            "picture_password": ["cat", "dog", "apple"],
            "age": 8,
            "avatar": "https://example.com/avatar.png",
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert any(
        error["msg"].endswith(
            "avatar must be a supported avatar id, local avatar asset path, or PNG/JPEG/WEBP data URL"
        )
        for error in response.json()["detail"]
    )


def test_child_create_rejects_malformed_inline_avatar_image(client, create_parent, auth_headers):
    parent = create_parent(email="bad.avatar.data@example.com")
    headers = auth_headers(parent)

    response = client.post(
        "/children",
        json={
            "name": "Bad Data",
            "picture_password": ["cat", "dog", "apple"],
            "age": 8,
            "avatar": "data:image/png;base64,not-valid-base64###",
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert any(
        "avatar image data is not valid base64" in error["msg"]
        for error in response.json()["detail"]
    )


def test_child_create_rejects_avatar_content_type_mismatch(client, create_parent, auth_headers):
    parent = create_parent(email="bad.avatar.mime@example.com")
    headers = auth_headers(parent)
    png_payload = _png_data_url().split(",", 1)[1]

    response = client.post(
        "/children",
        json={
            "name": "Bad Mime",
            "picture_password": ["cat", "dog", "apple"],
            "age": 8,
            "avatar": f"data:image/jpeg;base64,{png_payload}",
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert any(
        "avatar image type does not match the file content" in error["msg"]
        for error in response.json()["detail"]
    )


def test_child_create_rejects_oversized_inline_avatar_image(client, create_parent, auth_headers):
    parent = create_parent(email="bad.avatar.large@example.com")
    headers = auth_headers(parent)
    oversized = base64.b64encode(b"a" * ((2 * 1024 * 1024) + 1)).decode("ascii")

    response = client.post(
        "/children",
        json={
            "name": "Too Large",
            "picture_password": ["cat", "dog", "apple"],
            "age": 8,
            "avatar": f"data:image/png;base64,{oversized}",
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert any(
        "avatar image exceeds the 2 MB size limit" in error["msg"]
        for error in response.json()["detail"]
    )


def test_admin_child_update_rejects_malformed_avatar_image(
    client,
    db,
    seed_builtin_rbac,
    create_admin,
    create_parent,
    create_child,
    admin_headers,
):
    seed_builtin_rbac()
    admin = create_admin(email="avatar.admin@example.com", role_names=["super_admin"])
    parent = create_parent(email="avatar.owner@example.com")
    child = create_child(parent_id=parent.id, name="Managed Kid")

    response = client.patch(
        f"/admin/children/{child.id}",
        json={"avatar": "data:image/png;base64,broken!!"},
        headers=admin_headers(admin),
    )
    assert response.status_code == 422
    assert any(
        "avatar image data is not valid base64" in error["msg"]
        for error in response.json()["detail"]
    )
