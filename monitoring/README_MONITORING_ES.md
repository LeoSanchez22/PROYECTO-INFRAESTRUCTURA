# Monitoreo con Grafana y CloudWatch

## 1. Introducción

Este documento explica el funcionamiento del sistema de monitoreo implementado para la plataforma Academic Scheduler, centrado específicamente en la integración entre Grafana y AWS CloudWatch. Esta configuración permite la visualización en tiempo real de métricas del sistema, seguimiento de errores y análisis de rendimiento de la infraestructura.

## 2. Arquitectura de Monitoreo

La arquitectura de monitoreo se compone de dos componentes principales:

- **AWS CloudWatch**: Servicio de monitoreo y observabilidad que recopila datos operativos en forma de logs, métricas y eventos para proporcionar una visión unificada de los recursos de AWS, las aplicaciones y los servicios.

- **Grafana**: Plataforma de visualización que se conecta a CloudWatch para crear dashboards interactivos y personalizables que muestran las métricas en tiempo real.

El flujo de datos es el siguiente:
1. La aplicación genera métricas y logs
2. CloudWatch recopila y almacena estos datos
3. Grafana consulta CloudWatch y visualiza la información en dashboards

## 3. Configuración de Grafana

### Instalación y Acceso

```bash
# Iniciar el contenedor de Grafana
cd monitoring
docker-compose up -d
```

Acceso a Grafana:
- URL: http://localhost:3000
- Usuario: admin
- Contraseña: admintest123 (configurable en el archivo .env)

### Configuración del Data Source de CloudWatch

Grafana viene preconfigurado con un data source de CloudWatch, pero puede ser necesario verificar o modificar esta configuración:

1. Ir a Configuración > Data Sources
2. Seleccionar "CloudWatch" o agregar nuevo si no existe
3. Configurar con las credenciales de AWS y la región correcta

## 4. Integración con CloudWatch

### Configuración de Credenciales AWS

Para permitir que Grafana acceda a los datos de CloudWatch, es necesario configurar las credenciales de AWS:

```bash
# Copiar el archivo de ejemplo
cp .env-example .env
```

Editar el archivo .env con sus credenciales:
```
AWS_ACCESS_KEY_ID=su_access_key_aquí
AWS_SECRET_ACCESS_KEY=su_secret_key_aquí
AWS_REGION=us-east-1
```

### Grupos de Logs

Los logs están organizados en los siguientes grupos en CloudWatch:
- `/academic-scheduler/api`: Logs relacionados con las API REST
- `/academic-scheduler/connection`: Eventos de conexión y sesiones de usuario
- `/academic-scheduler/resource`: Utilización de recursos (memoria, CPU)
- `/academic-scheduler/error`: Errores y excepciones del sistema

## 5. Dashboards Disponibles

Los dashboards preconfigurados incluyen:

### Monitoreo de Conexiones
- Usuarios concurrentes
- Estado de conexiones
- Tendencias de conexión a lo largo del tiempo

### Gestión de Recursos
- Utilización de RAM
- Uso de memoria a lo largo del tiempo
- Picos de consumo de recursos

### Gestión de Errores
- Errores de Lambda
- Distribución de tipos de error
- Errores 5XX
- Tasas de error a lo largo del tiempo

### Monitoreo de API REST
- Uso de métodos API (GET, POST, PUT, PATCH, DELETE)
- Latencia por método
- Volumen de solicitudes

## 6. Estructura de Logs

Los logs en CloudWatch siguen una estructura JSON estandarizada para facilitar las consultas y visualizaciones:

```json
{
  "timestamp": "2023-06-08T12:34:56Z",
  "logLevel": "INFO|ERROR|WARN",
  "service": "api|connection|resource|error",
  "message": "Descripción del evento",
  "metadata": {
    // Campos adicionales específicos del tipo de log
  }
}
```

### Ejemplos de Consultas CloudWatch

#### Análisis de Tasa de Errores
```
filter @message like "ERROR"
| stats count(*) as errorCount by bin(5m)
```

#### Tendencias de Uso de Recursos
```
filter @message like "MEMORY"
| stats avg(memoryUsedMB) as avgMemory by bin(15m)
```

#### Rendimiento de API
```
filter httpMethod in ["POST", "PUT", "PATCH", "DELETE"]
| stats avg(duration) as avgLatency by httpMethod, resourcePath
| sort avgLatency desc
```

## 7. Solución de Problemas Comunes

### No se muestran datos en los dashboards

1. **Verificar credenciales AWS**: Asegúrese de que las credenciales en el archivo .env sean correctas y tengan los permisos necesarios.

2. **Comprobar configuración del data source**: Verifique que el data source de CloudWatch esté correctamente configurado en Grafana.

3. **Esperar tiempo de propagación**: CloudWatch puede tener un retraso de varios minutos antes de que los datos estén disponibles para consulta.

4. **Verificar rango de tiempo**: Ajuste el rango de tiempo en Grafana para asegurarse de que está mostrando el período correcto.

### Errores de conexión con CloudWatch

1. **Verificar conectividad de red**: Asegúrese de que el contenedor de Grafana tenga acceso a internet para conectarse a la API de AWS.

2. **Comprobar permisos IAM**: Las credenciales AWS deben tener permisos para leer métricas y logs de CloudWatch.

3. **Verificar región correcta**: Asegúrese de que está utilizando la misma región donde se están almacenando sus logs y métricas.

### Rendimiento lento de los dashboards

1. **Optimizar consultas**: Las consultas muy amplias o sin filtros pueden ser lentas. Añada filtros específicos para mejorar el rendimiento.

2. **Ajustar intervalo de refresco**: Reducir la frecuencia de actualización automática para consultas pesadas.

3. **Utilizar períodos de agregación**: Use funciones de agregación en CloudWatch Insights para reducir el volumen de datos transferidos.

