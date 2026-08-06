#!/usr/bin/env bash
set -Eeuo pipefail

MODULE="hid-warrior-dash"
DRIVER="warrior_dash"
VERSION="1.1.0"
OLD_VERSION="1.0.0"
KERNEL="$(uname -r)"
SRC="/usr/src/${MODULE}-${VERSION}"
LOAD_CONF="/etc/modules-load.d/${MODULE}.conf"
MODPROBE_CONF="/etc/modprobe.d/${MODULE}.conf"
INITRAMFS_MODULES="/etc/initramfs-tools/modules"
REBIND_SCRIPT="/usr/local/sbin/warrior-dash-rebind"
SERVICE="/etc/systemd/system/warrior-dash-rebind.service"
UDEV_RULE="/etc/udev/rules.d/99-warrior-dash.rules"

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

remove_initramfs_entry() {
  local tmp

  [[ -f "${INITRAMFS_MODULES}" ]] || return 0
  tmp="$(mktemp)"
  grep -vxF "${MODULE}" "${INITRAMFS_MODULES}" >"${tmp}" || true
  "${SUDO[@]}" install -m 0644 "${tmp}" "${INITRAMFS_MODULES}"
  rm -f "${tmp}"
}

uninstall_fix() {
  echo "Removendo o corretor HID do Warrior Dash..."

  "${SUDO[@]}" systemctl disable --now warrior-dash-rebind.service 2>/dev/null || true
  "${SUDO[@]}" rm -f \
    "${SERVICE}" \
    "${UDEV_RULE}" \
    "${REBIND_SCRIPT}" \
    "${LOAD_CONF}" \
    "${MODPROBE_CONF}"

  remove_initramfs_entry

  "${SUDO[@]}" systemctl daemon-reload
  "${SUDO[@]}" udevadm control --reload-rules
  "${SUDO[@]}" modprobe -r "${MODULE}" 2>/dev/null || true
  "${SUDO[@]}" dkms remove -m "${MODULE}" -v "${VERSION}" --all 2>/dev/null || true
  "${SUDO[@]}" dkms remove -m "${MODULE}" -v "${OLD_VERSION}" --all 2>/dev/null || true
  "${SUDO[@]}" rm -rf "/usr/src/${MODULE}-${VERSION}" "/usr/src/${MODULE}-${OLD_VERSION}"
  "${SUDO[@]}" depmod -a
  "${SUDO[@]}" update-initramfs -u -k all

  echo
  echo "Removido. Desconecte e reconecte o mouse/receptor."
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall_fix
  exit 0
fi

echo "Instalando dependências..."
"${SUDO[@]}" apt update
"${SUDO[@]}" apt install -y \
  dkms \
  build-essential \
  "linux-headers-${KERNEL}" \
  initramfs-tools \
  mokutil

echo "Criando o módulo DKMS..."
"${SUDO[@]}" dkms remove -m "${MODULE}" -v "${VERSION}" --all 2>/dev/null || true
"${SUDO[@]}" dkms remove -m "${MODULE}" -v "${OLD_VERSION}" --all 2>/dev/null || true
"${SUDO[@]}" rm -rf "${SRC}" "/usr/src/${MODULE}-${OLD_VERSION}"
"${SUDO[@]}" mkdir -p "${SRC}"

"${SUDO[@]}" tee "${SRC}/hid-warrior-dash.c" >/dev/null <<'EOF_MODULE'
#include <linux/module.h>
#include <linux/hid.h>
#include <linux/usb.h>
#include <linux/string.h>

#define USB_VENDOR_ID_TELINK            0x248a
#define USB_DEVICE_ID_WARRIOR_RECEIVER  0xfa02
#define USB_DEVICE_ID_WARRIOR_MOUSE     0xfb01

/*
 * O firmware anuncia cinco bits de botão, mas limita os usos HID aos
 * botões 1..3. O Linux então interpreta os bits 4 e 5 como duplicatas
 * inválidas do botão 3. Corrigimos Usage Maximum de 3 para 5.
 */
static const u8 warrior_bad_button_desc[] = {
	0x05, 0x09,       /* Usage Page (Button) */
	0x19, 0x01,       /* Usage Minimum (Button 1) */
	0x29, 0x03,       /* Usage Maximum (Button 3) - incorreto */
	0x15, 0x00,       /* Logical Minimum (0) */
	0x25, 0x01,       /* Logical Maximum (1) */
	0x75, 0x01,       /* Report Size (1) */
	0x95, 0x05,       /* Report Count (5) */
	0x81, 0x02        /* Input (Data,Var,Abs) */
};

static const __u8 *warrior_report_fixup(struct hid_device *hdev,
					__u8 *rdesc, unsigned int *rsize)
{
	unsigned int i;

	if (*rsize < sizeof(warrior_bad_button_desc))
		return rdesc;

	for (i = 0; i <= *rsize - sizeof(warrior_bad_button_desc); i++) {
		if (!memcmp(&rdesc[i], warrior_bad_button_desc,
			    sizeof(warrior_bad_button_desc))) {
			rdesc[i + 5] = 0x05;
			hid_info(hdev,
				 "fixed malformed button usage range (3 -> 5)\n");
			break;
		}
	}

	return rdesc;
}

static const struct hid_device_id warrior_devices[] = {
	{ HID_USB_DEVICE(USB_VENDOR_ID_TELINK,
			 USB_DEVICE_ID_WARRIOR_RECEIVER) },
	{ HID_USB_DEVICE(USB_VENDOR_ID_TELINK,
			 USB_DEVICE_ID_WARRIOR_MOUSE) },
	{ }
};
MODULE_DEVICE_TABLE(hid, warrior_devices);

static struct hid_driver warrior_driver = {
	.name = "warrior_dash",
	.id_table = warrior_devices,
	.report_fixup = warrior_report_fixup,
};
module_hid_driver(warrior_driver);

MODULE_AUTHOR("Local Warrior Dash Linux fix");
MODULE_DESCRIPTION("HID descriptor fix for Warrior Dash 248a:fa02/fb01");
MODULE_LICENSE("GPL");
EOF_MODULE

"${SUDO[@]}" tee "${SRC}/Makefile" >/dev/null <<'EOF_MAKE'
obj-m += hid-warrior-dash.o
EOF_MAKE

"${SUDO[@]}" tee "${SRC}/dkms.conf" >/dev/null <<EOF_DKMS
PACKAGE_NAME="${MODULE}"
PACKAGE_VERSION="${VERSION}"
BUILT_MODULE_NAME[0]="${MODULE}"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
EOF_DKMS

echo "Compilando para o kernel ${KERNEL}..."
"${SUDO[@]}" dkms add -m "${MODULE}" -v "${VERSION}"
"${SUDO[@]}" dkms build -m "${MODULE}" -v "${VERSION}" -k "${KERNEL}"
"${SUDO[@]}" dkms install -m "${MODULE}" -v "${VERSION}" -k "${KERNEL}"
"${SUDO[@]}" depmod -a

echo "Configurando carregamento persistente..."
echo "${MODULE}" | "${SUDO[@]}" tee "${LOAD_CONF}" >/dev/null

"${SUDO[@]}" tee "${MODPROBE_CONF}" >/dev/null <<EOF_MODPROBE
# Carrega o corretor antes do driver HID genérico quando possível.
softdep hid_generic pre: ${MODULE}
EOF_MODPROBE

"${SUDO[@]}" touch "${INITRAMFS_MODULES}"
if ! grep -qxF "${MODULE}" "${INITRAMFS_MODULES}"; then
  echo "${MODULE}" | "${SUDO[@]}" tee -a "${INITRAMFS_MODULES}" >/dev/null
fi

"${SUDO[@]}" tee "${REBIND_SCRIPT}" >/dev/null <<'EOF_REBIND'
#!/usr/bin/env bash
set -u

MODULE="hid-warrior-dash"
DRIVER="warrior_dash"

modprobe "${MODULE}" || exit 1

# Aguarda o receptor ou o mouse USB aparecer durante o boot.
for _ in $(seq 1 40); do
  found=0
  bound=0

  for dev in \
    /sys/bus/hid/devices/0003:248A:FA02.* \
    /sys/bus/hid/devices/0003:248A:FB01.*; do
    [[ -e "${dev}" ]] || continue
    found=1
    id="${dev##*/}"
    current=""

    if [[ -L "${dev}/driver" ]]; then
      current="$(basename "$(readlink -f "${dev}/driver")")"
    fi

    if [[ "${current}" != "${DRIVER}" ]]; then
      if [[ -n "${current}" && -w "/sys/bus/hid/drivers/${current}/unbind" ]]; then
        printf '%s' "${id}" >"/sys/bus/hid/drivers/${current}/unbind" || true
      fi

      if [[ -w "/sys/bus/hid/drivers/${DRIVER}/bind" ]]; then
        printf '%s' "${id}" >"/sys/bus/hid/drivers/${DRIVER}/bind" 2>/dev/null || true
      fi
    fi

    if [[ -L "${dev}/driver" ]] && \
       [[ "$(basename "$(readlink -f "${dev}/driver")")" == "${DRIVER}" ]]; then
      bound=1
    fi
  done

  if (( found == 1 && bound == 1 )); then
    exit 0
  fi

  sleep 0.25
done

# Não é erro se o mouse estiver desligado ou desconectado.
exit 0
EOF_REBIND
"${SUDO[@]}" chmod 0755 "${REBIND_SCRIPT}"

"${SUDO[@]}" tee "${SERVICE}" >/dev/null <<EOF_SERVICE
[Unit]
Description=Bind Warrior Dash mouse to its HID fix driver
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=${REBIND_SCRIPT}

[Install]
WantedBy=multi-user.target
EOF_SERVICE

"${SUDO[@]}" tee "${UDEV_RULE}" >/dev/null <<'EOF_UDEV'
ACTION=="add", SUBSYSTEM=="hid", ENV{HID_ID}=="0003:0000248A:0000FA02", TAG+="systemd", ENV{SYSTEMD_WANTS}+="warrior-dash-rebind.service"
ACTION=="add", SUBSYSTEM=="hid", ENV{HID_ID}=="0003:0000248A:0000FB01", TAG+="systemd", ENV{SYSTEMD_WANTS}+="warrior-dash-rebind.service"
EOF_UDEV

"${SUDO[@]}" update-initramfs -u -k all
"${SUDO[@]}" systemctl daemon-reload
"${SUDO[@]}" udevadm control --reload-rules
"${SUDO[@]}" systemctl enable warrior-dash-rebind.service

echo "Carregando e reatribuindo o mouse agora..."
if ! "${SUDO[@]}" modprobe "${MODULE}"; then
  echo
  echo "O módulo foi compilado, mas o kernel recusou carregá-lo."
  if mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    echo "Secure Boot está ativo. Será necessário registrar a chave MOK do DKMS"
    echo "ou desativar Secure Boot no firmware antes de carregar o módulo."
  fi
  exit 1
fi

"${SUDO[@]}" systemctl restart warrior-dash-rebind.service

echo
echo "Instalação concluída."
echo "O módulo agora é carregado no boot e o mouse é reatribuído automaticamente."
echo "Teste os botões agora. Depois reinicie o computador para validar a persistência."
echo
echo "Para remover futuramente:"
echo "  bash \"$0\" --uninstall"
