# Ronda Vigía

Control de rondas para guardias de seguridad: terminal de marcación de puntos
de control, bitácora y reportes de cumplimiento.

Aplicación web de un solo archivo, sin dependencias ni servidor. Se instala en
el teléfono desde el navegador y funciona sin señal.

## Qué hace

- **Ronda** — el guardia inicia el recorrido y marca cada punto escribiendo el
  código del tag. La app valida que el código pertenezca a la ruta, que no esté
  ya marcado y, si la ruta lo exige, que se respete el orden. Cada marca queda
  con hora y desfase contra el minuto programado: *a tiempo*, *anticipado* o
  *retrasado*. Admite reportar novedad con observación y adjuntar ubicación.
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

En el navegador de cada equipo (`localStorage`). Los dispositivos **no**
comparten información entre sí. Usa Configuración → Respaldo con regularidad:
si se borran los datos del sitio, la bitácora de ese equipo se pierde.

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
