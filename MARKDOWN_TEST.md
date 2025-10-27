# Documento de Prueba - Sintaxis Markdown Completa

Este documento contiene ejemplos de todas las reglas de sintaxis Markdown que ahora soporta el conversor.

## 1. PÁRRAFOS Y SALTOS DE LÍNEA

Este es un párrafo normal.
Este es otro texto con salto de línea (2 espacios antes).

Este es un nuevo párrafo separado por línea en blanco.

## 2. ENCABEZADOS

# Encabezado nivel 1
## Encabezado nivel 2
### Encabezado nivel 3
#### Encabezado nivel 4
##### Encabezado nivel 5
###### Encabezado nivel 6

Encabezado alternativo 1
========================

Encabezado alternativo 2
------------------------

## 3. ÉNFASIS

Texto con *cursiva usando asteriscos*.
Texto con _cursiva usando guiones bajos_.

Texto con **negrita usando asteriscos**.
Texto con __negrita usando guiones bajos__.

Texto con ***cursiva y negrita usando asteriscos***.
Texto con ___cursiva y negrita usando guiones bajos___.

Texto con ~~tachado~~.

## 4. LISTAS DESORDENADAS

- Elemento 1
- Elemento 2
- Elemento 3
    - Subelemento 3.1 (4 espacios)
    - Subelemento 3.2
- Elemento 4

* Alternativa con asterisco
+ Alternativa con más

## 5. LISTAS ORDENADAS

1. Primer elemento
2. Segundo elemento
3. Tercer elemento
    - Subelemento con viñeta
    - Otro subelemento
4. Cuarto elemento

## 6. LISTAS DE TAREAS

- [ ] Tarea pendiente 1
- [ ] Tarea pendiente 2
- [x] Tarea completada
- [X] Otra tarea completada

## 7. CITAS

> Esta es una cita simple.

> Esta es una cita
> con múltiples líneas.
>
> Y múltiples párrafos.

> Cita principal
> > Cita anidada dentro
>
> Continuación de la cita principal

## 8. CÓDIGO

Código inline: `const x = 42;`

Bloque de código con triple backtick:

```
function hello() {
  console.log("Hello, World!");
}
```

Bloque de código con 4 espacios:

    def hello():
        print("Hello, World!")

Bloque de código con triple tilde:

~~~
let greeting = "Hello";
console.log(greeting);
~~~

## 9. ENLACES

[Enlace simple](https://www.ejemplo.com)

[Enlace con título](https://www.ejemplo.com "Título del enlace")

<https://www.ejemplo-automatico.com>

Enlace por referencia: [texto del enlace][ref1]

[ref1]: https://www.referencia.com "Título opcional"

## 10. IMÁGENES

![Texto alternativo](https://via.placeholder.com/150)

![Imagen con título](https://via.placeholder.com/200 "Este es el título")

Imagen por referencia: ![Descripción][img1]

[img1]: https://via.placeholder.com/300 "Título de la imagen"

## 11. REGLAS HORIZONTALES

Regla con guiones:

---

Regla con asteriscos:

***

Regla con guiones bajos:

___

Regla con espacios:

- - -

## 12. TABLAS

| Columna 1 | Columna 2 | Columna 3 |
|-----------|-----------|-----------|
| Celda 1   | Celda 2   | Celda 3   |
| Celda 4   | Celda 5   | Celda 6   |
| Celda 7   | Celda 8   | Celda 9   |

| Encabezado | Otro Encabezado |
|:-----------|----------------:|
| Izquierda  | Derecha         |
| Centro     | Derecha         |

## 13. CARACTERES ESCAPADOS

Estos caracteres están escapados: \* \_ \# \[ \] \( \) \\ \` \{ \}

\*Este texto NO está en cursiva\*

\## Esto NO es un encabezado

## 14. FORMATOS EXTENDIDOS

Texto con ==resaltado==.

Superíndice: E = mc^2^

Subíndice: H~2~O

## 15. COMBINACIONES

**Negrita con [enlace](https://ejemplo.com) dentro**

*Cursiva con `código` inline*

Lista con código:

- Elemento con `código inline`
- Otro elemento con **negrita**
    - Subelemento con ***negrita y cursiva***

> Cita con **negrita** y *cursiva*
>
> Y con `código inline`

## 16. TEXTO COMPLEJO

Este es un párrafo con **negrita**, *cursiva*, `código`, y un [enlace](https://ejemplo.com "con título").
También tiene un salto de línea.

Y termina en un nuevo párrafo con ~~texto tachado~~ y ==texto resaltado==.

---

¡Fin del documento de prueba!
