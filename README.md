# oci-free-vpn

Oracle Cloud **Always Free** 인스턴스에 **Tailscale exit node**를 올려, 월 0원으로 상시 켜진 개인 VPN(해외 출구)을 만드는 Terraform 구성입니다.

- 카드 결제 없이 **월 0원** (Always Free 한도 내)
- 출구 IP는 **나 혼자 쓰는 전용 IP**
- 클라이언트에서 켜는 건 **클릭 한 번** (Tailscale)
- 개인 상황(**오라클 키·리전** 정도)만 채우면 `terraform apply` 한 번으로 끝

> 배경과 개념 설명은 블로그 글 **"무료 VPN 구축하기 w/ Oracle Cloud"** 참고.
> VPN 서버 소프트웨어로는 Tailscale을 썼지만, 같은 박스에 WireGuard·OpenVPN을 직접 올려도 됩니다.

## 준비물

1. **OCI 계정** — Home Region이 **원하는 출구 지역(예: 미국)** 인 계정.
   Always Free 자원은 home region에만 생기고, home region은 **나중에 바꿀 수 없습니다(영구)**.
   원하는 지역이 정해져 있다면, 그 지역을 home으로 하는 계정을 새로 만드세요.
2. **OCI CLI 인증** — `~/.oci/config`(API 키) 또는 `OCI_*` 환경변수. 키는 이 저장소에 들어가지 않습니다(provider가 읽음).
3. **관리용 SSH 키페어**
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/oci-vpn -C oci-vpn
   ```
4. **Tailscale auth key** — reusable · pre-authorized · tagged(`tag:exit-node`) 권장.
   상시 노드이므로 **non-ephemeral(영구) 키**를 쓰세요. ephemeral 키는 노드가
   오프라인이 길어지면 tailnet에서 제거돼, 재부팅 후 자동연결이 깨질 수 있습니다.
   https://login.tailscale.com/admin/settings/keys

## 설정 (여기만 채우면 됩니다)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`에서 **필수 4개**만 본인 값으로 바꾸면 됩니다.

| 변수 | 설명 |
|------|------|
| `compartment_id` | 본인 Compartment(보통 Tenancy) OCID |
| `region` | 본인 계정의 **Home Region** (예: `us-ashburn-1`) |
| `ts_authkey` | Tailscale auth key *(파일 대신 `TF_VAR_ts_authkey` 환경변수 권장)* |
| `ssh_allowed_cidr` | 관리 SSH 허용 IP — 본인 `IP/32`로 좁히기 |

나머지(shape, 호스트명, CIDR 등)는 기본값으로 충분합니다. 기본 shape은 **`VM.Standard.E2.1.Micro`** — 인기 리전에서 ARM `A1.Flex`가 `Out of host capacity`로 안 잡히는 경우가 많은데, exit node엔 Micro로도 충분합니다.

## 배포

```bash
export TF_VAR_ts_authkey='tskey-auth-...'   # authkey를 파일에 안 넣었다면

terraform init
terraform apply
```

`apply`가 끝나면 `instance_public_ip`(출구 IP)와 `ssh_command`가 출력됩니다.
첫 부팅 때 cloud-init이 자동으로:

- IPv4/IPv6 forwarding 활성화
- **OCI Ubuntu 이미지 기본 `FORWARD -j REJECT` 규칙 제거** — 안 지우면 라우팅 트래픽이 조용히 드롭되는, OCI exit node의 대표 함정
- Tailscale 설치 후 `tailscale up --advertise-exit-node`

## 배포 후 3단계

1. **Tailscale admin 콘솔에서 exit node 승인**
   Machines → 새 노드 → Edit route settings → *Use as exit node*.
   (`autoApprovers` ACL에 `tag:exit-node`를 걸면 이 단계 생략 가능.)
2. **클라이언트에서 선택**
   Tailscale 메뉴 막대 → Exit node → `oci-vpn-exit`, 또는
   `tailscale set --exit-node=oci-vpn-exit`.
3. **검증**
   ```bash
   curl https://ifconfig.me   # 출력이 instance_public_ip 이면 성공
   ```

## 참고

- **출구 IP 고정:** 기본은 ephemeral public IP라 인스턴스 재생성 시 바뀝니다. 고정하려면 OCI 콘솔에서 Reserved Public IP를 예약(Always Free 한도 내 무료)해 VNIC에 붙이세요.
- **대역폭:** Always Free는 넉넉한 월 egress를 포함합니다. 정확한 현재 한도는 [OCI Always Free 공식 문서](https://www.oracle.com/cloud/free/)로 확인하세요(시기에 따라 변동).
- **용량 부족(`Out of host capacity`):** 재시도하거나, 덜 붐비는 리전으로 바꾸거나, 기본 `E2.1.Micro`를 그대로 쓰세요.
- **정리:** 다 쓰면 `terraform destroy`.

## 구성

```
terraform/
├── versions.tf                 # provider (oracle/oci)
├── variables.tf                # 필수/선택 변수
├── main.tf                     # VCN·IGW·라우팅·보안리스트·인스턴스
├── outputs.tf                  # instance_public_ip, ssh_command 등
├── cloud-init.yaml.tftpl       # 첫 부팅: FORWARD reject 제거 + Tailscale up
└── terraform.tfvars.example    # 여기를 복사해서 본인 값 채우기
```
