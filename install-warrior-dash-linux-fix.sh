#!/usr/bin/env bash
set -Eeuo pipefail

MODULE="hid-warrior-dash"
VERSION="1.0.0"
KERNEL="$(uname -r)"
SRC="/usr/src/${MODULE}-${VERSION}"
LOAD_CONF="/etc/modules-load.d/${MODULE}.conf"

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

uninstall_fix() {
  echo "Removendo o corretor HID do Warrior Dash..."
  "${SUDO[@]}" modprobe -r "${MODULE}" 2>/dev/null || true
  "${SUDO[@]}" dkms remove -m "${MODULE}" -v "${VERSION}" --all 2>/dev/null || true
  "${SUDO[@]}" rm -rf "${SRC}" "${LOAD_CONF}"
  "${SUDO[@]}" depmod -a
  echo
  echo "Removido. Desconecte e reconecte o mouse/receptor."
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall_fix
  exit 0
fi

echo "Instalando dependências..."
"${SUDO[@]}" apt update
"${SUDO[@]}" apt install -y dkms build-essential "linux-headers-${KERNEL}" mokutil

echo "Criando o módulo DKMS..."
"${SUDO[@]}" dkms remove -m "${MODULE}" -v "${VERSION}" --all 2>/dev/null || true
"${SUDO[@]}" rm -rf "${SRC}"
"${SUDO[@]}" mkdir -p "${SRC}"

"${SUDO[@]}" tee "${SRC}/hid-warrior-dash.c" >/dev/null <<'EOF'
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
EOF

"${SUDO[@]}" tee "${SRC}/Makefile" >/dev/null <<'EOF'
obj-m += hid-warrior-dash.o
EOF

"${SUDO[@]}" tee "${SRC}/dkms.conf" >/dev/null <<EOF
PACKAGE_NAME="${MODULE}"
PACKAGE_VERSION="${VERSION}"
BUILT_MODULE_NAME[0]="${MODULE}"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
EOF

echo "Compilando para o kernel ${KERNEL}..."
"${SUDO[@]}" dkms add -m "${MODULE}" -v "${VERSION}"
"${SUDO[@]}" dkms build -m "${MODULE}" -v "${VERSION}" -k "${KERNEL}"
"${SUDO[@]}" dkms install -m "${MODULE}" -v "${VERSION}" -k "${KERNEL}"
echo "${MODULE}" | "${SUDO[@]}" tee "${LOAD_CONF}" >/dev/null
"${SUDO[@]}" depmod -a

echo "Carregando o módulo..."
if ! "${SUDO[@]}" modprobe "${MODULE}"; then
  echo
  echo "O módulo foi compilado, mas o kernel recusou carregá-lo."
  if mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    echo "Secure Boot está ativo. Será necessário registrar a chave MOK do DKMS"
    echo "ou desativar Secure Boot no firmware antes de carregar o módulo."
  fi
  exit 1
fi

echo
echo "Instalação concluída."
echo "Agora desconecte o CABO e o RECEPTOR, espere 3 segundos e conecte somente"
echo "o modo que deseja usar. Os botões laterais devem virar Back e Forward."
echo
echo "Para remover futuramente:"
echo "  bash \"$0\" --uninstall"
