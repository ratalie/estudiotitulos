# Arquitectura Funcional - Plataforma Estudio de Títulos

## Visión General

Sistema automatizado para análisis de expedientes de estudio de títulos en Colombia, utilizando IA generativa (AWS Bedrock) para automatizar la revisión legal y generar reportes estructurados.

## Componentes Funcionales

### 1. Intake & Expedientes

**Responsabilidad**: Gestión del ciclo de vida de casos

**Funcionalidades**:
- Crear expediente (básico o due diligence)
- Asignar código único
- Definir alcance y partes involucradas
- Versionado auditable
- Tracking de estado

**Entidades**:
- Case (expediente)
- Property (inmueble)
- Parties (partes: vendedor, comprador, representantes)

### 2. Gestión Documental

**Responsabilidad**: Ingesta, clasificación y almacenamiento de documentos

**Funcionalidades**:
- Carga de PDFs, imágenes, documentos
- Clasificación automática (escritura, cédula, certificado, etc.)
- Deduplicación por hash
- Evidencia de origen (fuente, fecha, responsable)
- Versionado de documentos

**Tipos de Documentos**:
- Escrituras públicas
- Certificados de tradición y libertad
- Cédulas de ciudadanía / Pasaportes
- Certificados de existencia y representación legal
- Paz y salvos (predial, valorización, administración)
- Licencias urbanísticas
- Reglamentos de propiedad horizontal

### 3. Extracción y Estructuración

**Responsabilidad**: OCR y extracción de datos estructurados

**Tecnologías**:
- Amazon Textract (OCR + forms + tables)
- Bedrock (post-procesamiento y normalización)

**Entidades Extraídas**:
- **Inmueble**: matrícula, cédula catastral, dirección, área, linderos
- **Tradición**: cadena de títulos, transferencias, fechas
- **Gravámenes**: hipotecas, embargos, limitaciones, patrimonio de familia
- **Impuestos**: predial (5 años), valorización, plusvalía
- **Partes**: nombres, identificación, poderes, facultades
- **Urbanismo**: uso de suelo, POT, UPZ, licencias

### 4. Motor de Análisis por Fases

**Responsabilidad**: Ejecutar análisis según metodología de estudio de títulos

#### Fases - Estudio Básico

**F1 - Recepción/Apertura**
- Crear expediente
- Validar información inicial
- Definir checklist de documentos

**F2 - Obtención de Documentos**
- Verificar documentos recibidos
- Identificar faltantes
- Registrar evidencias de fuente

**F3 - Tradición**
- Reconstruir cadena de títulos (mínimo 10 años o hasta título originario)
- Verificar consistencia de matrícula, dirección, área
- Validar transferencias legítimas
- **Gate 3**: ¿Cadena de tradición válida?

**F4 - Limitaciones/Gravámenes/Embargos**
- Identificar anotaciones vigentes
- Clasificar por tipo y riesgo
- Evaluar condiciones de levantamiento

**F5 - Tributario Inmueble**
- Verificar predial (últimos 5 años)
- Revisar valorización
- Validar plusvalía si aplica

**F6 - Verificación Vendedor**
- Persona Natural: capacidad legal, estado civil, poderes
- Persona Jurídica: existencia, representación legal, facultades, vigencia

#### Fases Adicionales - Due Diligence

**F7 - Urbanístico**
- Uso de suelo según POT/UPZ
- Licencias de construcción
- Normas urbanísticas aplicables
- Propiedad horizontal (si aplica)

**F8 - Tributario Exhaustivo**
- Retenciones
- Impuestos de notaría
- Análisis fiscal de partes

**F9 - Verificación Exhaustiva Vendedor**
- Background check
- Antecedentes judiciales
- Listas restrictivas

### 5. Gates (Puntos de Control)

**Decisiones Posibles**:
- **GO**: Continuar sin restricciones
- **GO_WITH_CONDITIONS**: Continuar con condiciones específicas
- **NO_GO**: Detener proceso

**Información Registrada**:
- Decisión
- Razonamiento (rationale)
- Evidencia de soporte
- Responsable
- Timestamp

**Gates Críticos**:
- Gate 3 (post-tradición): Validez de cadena
- Gate 4 (post-gravámenes): Riesgos aceptables
- Gate 6 (post-vendedor): Capacidad legal confirmada

### 6. Consolidación y Reporte

**Responsabilidad**: Generar reporte final estructurado

**Estructura del Reporte**:
1. **Carátula**: Datos del caso, fecha, responsables
2. **Resumen Ejecutivo**: Semáforo 🟢🟡🔴, conclusión general
3. **Identificación del Inmueble**: Matrícula, ubicación, área
4. **Análisis por Secciones**:
   - Tradición
   - Gravámenes y limitaciones
   - Situación tributaria
   - Verificación de partes
   - Urbanismo (si DD)
5. **Tabla de Hallazgos**: Categoría, severidad, descripción, recomendación
6. **Conclusiones y Recomendaciones**
7. **Anexos**: Referencias a documentos

**Semáforo**:
- 🟢 **Verde**: Sin hallazgos críticos, proceso puede continuar
- 🟡 **Amarillo**: Hallazgos que requieren atención, condiciones aplicables
- 🔴 **Rojo**: Hallazgos críticos, no recomendable continuar

**Formatos**:
- PDF (entrega a cliente)
- DOCX (editable para revisión)
- JSON (datos estructurados para integración)

## Flujo de Trabajo Completo

```
1. Cliente solicita estudio
   ↓
2. Analista crea caso (básico/DD)
   ↓
3. Sistema genera checklist de documentos
   ↓
4. Cliente/Analista sube documentos
   ↓
5. Sistema ejecuta OCR + extracción
   ↓
6. Bedrock Agent Orchestrator inicia workflow
   ↓
7. Ejecución de fases en orden
   ↓
8. Evaluación de gates
   ↓
9. Consolidación de hallazgos
   ↓
10. Generación de reporte
    ↓
11. Supervisor revisa y aprueba
    ↓
12. Cliente descarga reporte final
```

## Roles y Permisos

### Analista Legal
- Crear casos
- Subir documentos
- Ejecutar análisis
- Ver hallazgos
- Generar reportes preliminares

### Supervisor
- Todo lo del analista
- Aprobar reportes
- Modificar decisiones de gates
- Acceso a auditoría completa

### Cliente
- Ver estado de su caso
- Subir documentos faltantes
- Descargar reporte final
- Sin acceso a hallazgos intermedios

## Auditoría y Trazabilidad

Todos los eventos se registran:
- Quién realizó la acción
- Qué acción se realizó
- Cuándo se realizó
- Datos relevantes (redactados de PII)

Eventos auditables:
- Creación de caso
- Carga de documento
- Ejecución de fase
- Decisión de gate
- Generación de reporte
- Cambios de estado

## Métricas y KPIs

- Tiempo promedio por fase
- Tiempo total de procesamiento
- Tasa de hallazgos por severidad
- Tasa de GO/NO-GO por gate
- Documentos faltantes promedio
- Satisfacción del cliente
