---
name: wsl
description: Diagnóstico y mantenimiento de discos de WSL2 en Windows. Recupera espacio de C: compactando el ext4.vhdx de cualquier distro, lo respalda y lo configura como sparse para que no vuelva a crecer. Úsalo cuando el usuario diga que WSL o Docker ocupa demasiado espacio, que C: está lleno después de borrar archivos en Linux, que el .vhdx no se achica, cuando quiera compactar o respaldar una distro, activar sparseVhd o --set-sparse, o cuando wsl dé Wsl/Service/WSAETIMEDOUT. Triggers: "ext4.vhdx", "compactar wsl", "liberar espacio wsl", "sparse", "Optimize-VHD", "diskpart compact vdisk", "wsl --shutdown", "/wsl".
argument-hint: "[distro] [objetivo: diagnosticar | compactar | sparse | respaldar]"
---

# Skill: WSL — discos virtuales

Objetivo: que Windows recupere el espacio que Linux ya liberó dentro de una distro WSL2, sin perder datos, y que el disco no vuelva a inflarse.

Idioma: el del usuario.

## Por qué pasa

Cada distro WSL2 vive en un `ext4.vhdx` dinámico. El archivo **crece** cuando Linux escribe, pero **no se achica** cuando Linux borra. Borrar 100 GB dentro de la distro no devuelve nada a C: hasta que se compacta el `.vhdx` o se activa sparse.

## Reglas

- **Leer y diagnosticar es libre.** Ejemplos: `wsl --version`, `wsl -l -v`, `wsl --help`, leer el registro, `Get-Item` para ver tamaños, `fsutil sparse queryflag`, `df -h` dentro de la distro.
- **Antes de cada acción que cambie algo, dile al usuario en una línea qué haces y por qué, y espera su OK.** Un OK vale solo para esa acción. Esto incluye `fstrim`, editar `.wslconfig`, `wsl --shutdown`, compactar, copiar el respaldo, `--set-sparse` y arrancar la distro con el disco ya modificado.
- **Nunca** uses `wsl --unregister`, ni borres un `.vhdx`, ni pases `--allow-unsafe` sin preguntar explícitamente y explicar el riesgo. `--unregister` borra todo el contenido de la distro.
- **No inventes flags.** Verifica cada comando con `wsl --help` en la máquina real. El comportamiento de sparse, de export y de import cambió entre versiones de WSL.
- Compactar, copiar el disco y `--set-sparse` requieren **PowerShell como Administrador**. Si la terminal no lo es, avisa y detente.

## Particularidades de la salida de `wsl.exe`

- `wsl -l -v` y `wsl --help` imprimen UTF-16. En PowerShell aparecen con espacios entre letras. Para buscar texto en esa salida, límpiala así: `(wsl --help) -join "`n" -replace "`0",""`.
- `wsl --help` termina con código de salida distinto de 0. Eso no es un error.
- El idioma de la salida depende de Windows. No busques cadenas literales en inglés.

## 1. Diagnóstico (solo lectura)

```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
wsl --version
wsl -l -v
Get-Content "$env:USERPROFILE\.wslconfig"
Get-PSDrive C
Get-Command Optimize-VHD -ErrorAction SilentlyContinue   # disponible si el módulo Hyper-V está instalado
```

Ubica el disco de cada distro en el registro:

```powershell
Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' | ForEach-Object {
  $p = Get-ItemProperty $_.PSPath
  if ($p.DistributionName) {
    $vhd = (Join-Path $p.BasePath 'ext4.vhdx') -replace '^\\\\\?\\',''
    [pscustomobject]@{ Distro=$p.DistributionName; VHD=$vhd; GB=[math]::Round((Get-Item -LiteralPath $vhd).Length/1GB,1) }
  }
}
```

- Algunas distros, como `docker-desktop`, registran su `BasePath` con el prefijo `\\?\`. `Test-Path` y `Get-Item` sin `-LiteralPath` fallan con ese prefijo, por eso el script lo quita.
- Las distros de la Microsoft Store guardan su disco en `%LOCALAPPDATA%\Packages\<Paquete>\LocalState\ext4.vhdx`. Las importadas lo guardan donde se indicó al importarlas.
- Compara el tamaño del `.vhdx` con el uso real que reporta `wsl -d <Distro> -- df -h /`. La diferencia es lo que se puede recuperar.
- Si hay varias distros parecidas (por ejemplo `Ubuntu` y `Ubuntu-24.04`), son **instalaciones independientes**, cada una con su propio disco. Identifica la que se usa con:
  - el `*` de `wsl -l -v`, que marca la distro por defecto;
  - `/etc/os-release` y `whoami` dentro de cada una;
  - el `LastWriteTime` de cada `.vhdx`.

## 2. Flujo para recuperar espacio

Sigue este orden. Antes de cada paso, explica qué haces y pide el OK.

1. **`fstrim` con la distro corriendo**: `wsl -d <Distro> -u root -- sh -c "sync; fstrim -av"`.
   - Marca como libres los bloques que Linux ya no usa, para que la compactación pueda recuperarlos.
   - Es normal que reporte cientos de GiB: recorre todo el espacio libre del sistema de archivos, no solo lo borrado hoy.
2. **Configurar `.wslconfig`**: agrega `sparseVhd=true` en la sección `[experimental]`, sin tocar lo demás.
   - Solo afecta a los discos que se creen después. Los existentes no cambian.
3. **Apagar WSL**:
   - Pide al usuario cerrar Docker Desktop desde el ícono de la bandeja → *Quit*. Cerrar la ventana no basta.
   - Confirma que no queden procesos: `Get-Process | ? Name -like '*docker*'`.
   - Corre `wsl --shutdown` y verifica con `wsl -l -v` que todas las distros digan `Stopped`.
4. **Compactar** con WSL apagado:
   - Si existe `Optimize-VHD`, usa `Optimize-VHD -Path <vhdx> -Mode Full`.
   - Si no existe, usa un script de diskpart: `select vdisk file="<vhdx>"`, `attach vdisk readonly`, `compact vdisk`, `detach vdisk`.
   - Lánzalo en segundo plano y anota el tamaño antes y después.
5. **Respaldar** el disco ya compactado, antes de activar sparse:
   - Copia el archivo con `Copy-Item -LiteralPath <vhdx> <destino>` y compara que ambos tengan los mismos bytes.
   - Para restaurar: `wsl --shutdown` y reemplazar el original por la copia.
   - Otra opción, si `wsl --help` la lista: `wsl --export <Distro> <archivo> --format vhd`, que se restaura con `wsl --import ... --vhd`.
   - Respaldar **después** de compactar es lo que suele hacer que el respaldo quepa.
6. **Activar sparse**: `wsl --manage <Distro> --set-sparse true`.
   - Verifica con `fsutil sparse queryflag <vhdx>`.
   - Si WSL lo rechaza y pide `--allow-unsafe`, **detente**. Explica el riesgo y ofrece la alternativa: no usar sparse y compactar a mano cuando haga falta.
7. **Verificar**:
   - Arranca la distro y corre `df -h /`, `whoami` y `ls ~` para confirmar que inicia y que los datos están.
   - Revisa el espacio libre de C:.
   - Recuérdale al usuario que ya puede volver a abrir Docker.

## Riesgos y reversibilidad

| Paso | Riesgo | ¿Reversible? |
|---|---|---|
| `fstrim` | Muy bajo. Solo toca bloques vacíos. | No hay nada que deshacer: los datos no cambian. |
| `sparseVhd=true` en `.wslconfig` | Ninguno sobre datos existentes. | Sí, borrando la línea. |
| `wsl --shutdown` | Se pierde lo que no esté guardado en WSL y en Docker. | Sí, todo vuelve a arrancar. |
| Compactar | Bajo. Si se corta la luz o se interrumpe a mitad, el disco puede corromperse. | No se deshace, pero el contenido no cambia. |
| `--set-sparse true` | **El único con riesgo real.** Es experimental y hubo reportes de corrupción. Algunas versiones exigen `--allow-unsafe`. | Sí, con `--set-sparse false`. Un daño ya ocurrido no se revierte. |

El mayor riesgo general es no tener respaldo. Si el disco no cabe para exportarlo antes de compactar, respáldalo después de compactar y antes de `--set-sparse`.

## Lo que hay que esperar (observado en la práctica)

- **Duración**: compactar un `.vhdx` de ~240 GB tardó ~70 minutos, y copiar un `.vhdx` de ~129 GB al mismo disco, ~66 minutos. Ninguno de los dos muestra porcentaje de avance. Avísale al usuario y no inventes estimaciones.
- **No se llega al uso real**: tras compactar, el `.vhdx` quedó en ~129 GB con 92 GB usados en Linux. El `.vhdx` se libera en bloques grandes, y uno con aunque sea pocos datos no se puede liberar. Después de un borrado masivo, la fragmentación deja esa diferencia. Sparse con `fstrim` posterior puede recuperar parte de ella.
- **Espacio temporal**: mientras `Optimize-VHD` corre, el espacio libre de C: puede bajar varios GB. Lo devuelve al terminar.
- **`Copy-Item` reserva el archivo completo al empezar**: el tamaño del destino no indica avance. Para saber cuánto lleva, usa el `CreationTime` del archivo de destino.
- **El espacio libre de C: puede subir tras `wsl --shutdown`**: se liberan la swap y la memoria de la máquina virtual.
- **En un disco sparse, `Length` no es lo que ocupa**: mide el espacio libre de C: o el "Tamaño en disco" en Propiedades.

## Mantenimiento

- Con el disco sparse: después de borrar mucho dentro de Linux, corre `sudo fstrim -av`. Libera el espacio en Windows sin apagar nada.
- Sin sparse: repite `fstrim`, `wsl --shutdown` y la compactación cuando el `.vhdx` vuelva a crecer mucho.
- Cuando el disco sparse lleve unos días funcionando bien, el respaldo se puede borrar. Hazlo solo con el OK del usuario.
- `docker-desktop` suele pesar poco. Los datos de Docker viven en otro disco: revisa su tamaño antes de proponer compactarlo.

## Si `wsl` da `Wsl/Service/WSAETIMEDOUT`

Suele pasar tras escaneos o borrados masivos que fragmentan la RAM del kernel de WSL. Si todavía hay una shell abierta dentro de la distro, corre como root:

```sh
sync; echo 3 > /proc/sys/vm/drop_caches; echo 1 > /proc/sys/vm/compact_memory
```

Si no hay acceso, `wsl --shutdown` desde Windows. Cuenta como acción que cambia algo: pide el OK.

## Antipatrones

- Compactar con la distro o Docker corriendo.
- Encadenar varias acciones con un solo OK.
- Forzar `--allow-unsafe` o `--unregister` para "terminar rápido".
- Usar flags sacados de memoria sin verificarlos con `wsl --help`.
- Hacer polling o inventar porcentajes durante operaciones largas.
- Prometer que el `.vhdx` quedará igual al uso que reporta `df`.
