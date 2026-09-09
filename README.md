# Ronda Vigía

Control de rondas para guardias de seguridad: terminal de marcación de puntos
de control, bitácora y reportes de cumplimiento.

Aplicación web de un solo archivo, sin dependencias ni servidor. Se instala en
el teléfono desde el navegador y funciona sin señal.

## Cuentas y roles

Cada persona entra con su usuario y su clave, y ve sólo su pantalla:

| Rol | Qué ve |
|---|---|
| **Administrador** | Todo: instalaciones, usuarios, puntos, rutas, personal, rondas y reportes de cualquier instalación. |
| **Guardia** | El terminal de marcación y sus propias rondas. No entra a configuración ni ve las rondas de otros. |
| **Cliente** | Bitácora y reportes de su instalación, sin poder modificar nada ni ver otras instalaciones. |

La primera vez que se abre en un equipo, la app pide crear la cuenta de
administrador. Desde ahí se dan de alta las demás.

> **Esto no es seguridad.** Todo corre en el navegador: las claves se guardan en
> el propio equipo y las valida el mismo código de la página. Sirve para separar
> vistas y evitar cambios por descuido, no para resistir a alguien que quiera
> saltárselo a propósito. Para eso hace falta un servidor que valide del otro lado.

## Instalaciones

Cada instalación es un sitio con su cliente, sus puntos de control, sus rutas y
su personal. El administrador cambia de una a otra con el selector de la barra
superior; el cliente sólo accede a la suya.

## Qué hace

- **Ronda** — el guardia inicia el recorrido y marca cada punto **escaneando su
  código QR** o escribiendo el código a mano. La app valida que el código
  pertenezca a la ruta, que no esté ya marcado y, si la ruta lo exige, que se
  respete el orden. Cada marca queda con hora y desfase contra el minuto
  programado: *a tiempo*, *anticipado* o *retrasado*.
- **Fotos** — hasta tres por punto, tomadas con la cámara. Se comprimen a
  ~1024 px antes de guardarse (una foto de 2 MB queda en unos 60 KB) y viven en
  IndexedDB, no en `localStorage`. Se ven en la bitácora y se pueden compartir.
- **Ubicación** — coordenadas con su precisión en metros y enlace al mapa.
  Van también en el CSV, en columnas separadas de latitud y longitud.
- **Etiquetas QR** — genera e imprime una etiqueta por punto de control, con su
  código, nombre y zona, para plastificar y pegar en terreno.
- **Marca manual** — si el tag no responde, se registra igual pero exige
  justificación y queda señalada como manual en la bitácora.
- **Bitácora** — todas las marcas, filtrables por período, guardia y ruta. Los
  puntos no marcados al cerrar una ronda quedan como *omitidos*. Exporta a CSV.
- **Reportes** — cobertura de puntos, porcentaje dentro de tolerancia,
  omisiones y novedades, cobertura diaria, desempeño por guardia y ranking de
  puntos más omitidos.
- **Configuración** — puntos de control, rutas (por tramos, admite pasar dos
  veces por el mismo punto) y personal.
- **Respaldo** — descarga y restauración de todos los datos en un archivo JSON.

## Dónde quedan los datos

En el navegador de cada equipo: los registros en `localStorage` y las fotos en
IndexedDB. Los dispositivos **no** comparten información entre sí, y las fotos
tomadas en un teléfono no viajan solas a ningún otro. Usa Configuración →
Respaldo con regularidad: si se borran los datos del sitio, la bitácora y las
fotos de ese equipo se pierden.

Para que varios equipos compartan la misma bitácora en vivo hace falta un
servidor con base de datos, que es un paso aparte.

## Publicar

Los archivos se sirven tal cual, sin compilar. Con GitHub Pages:
*Settings → Pages → Deploy from a branch → `main` → `/ (root)`*.

## Actualizar

Al subir una versión nueva de `index.html`, incrementa el número de caché en la
primera línea de `sw.js`:

```js
const CACHE = "ronda-vigia-v1";   // -> v2, v3, ...
```

Sin eso, los teléfonos con la app ya instalada seguirán mostrando la versión
guardada.

## Instalar en el teléfono

- **Android (Chrome):** menú → *Instalar aplicación*.
- **iPhone (Safari):** Compartir → *Agregar a inicio*.

No pasa por ninguna tienda.
