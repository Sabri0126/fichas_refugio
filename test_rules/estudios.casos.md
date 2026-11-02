# Casos de la subcolección `perros/{id}/estudios`

No hay emulador de reglas en el repo. Chemy puede contrastarlos al publicar `firestore.rules`.

- Visitante (sin sesión): no lee ni escribe `perros/{id}/estudios/{estudioId}`.
- Usuario logueado que no está en `isStaff()`: no lee ni escribe.
- Personal: lee, crea, edita y borra un estudio.
- `perros/{id}` sigue siendo de lectura pública para el visitante y para cualquiera.
