# Proyecto de Infraestructura como Código en AWS

Este proyecto implementa una infraestructura segura para una aplicación web utilizando Terraform con los siguientes componentes:

- Amazon S3 para alojar la interfaz web estática y almacenar PDFs.
- Amazon CloudFront para la entrega de contenido con protección de WAF.
- AWS WAF para seguridad y limitación de tasas.
- AWS AppSync para la API GraphQL.
- AWS Lambda para el procesamiento backend sin servidor.
- Amazon Cognito para la autenticación.
- AWS Fargate para ejecutar la generación de horarios en contenedores.
- Amazon ECR para almacenar imágenes Docker.
- Amazon DynamoDB para almacenar el historial de generación de horarios.

## Integrantes

| Apellidos y Nombres | Código |
| ------------------ | ------ |
| Sanchez Romero, Leonardo Gabriel | 263444 |
| Sanchez Chuquimango, Diego | 258084 |

## Entorno de Desarrollo

Este proyecto fue desarrollado en el siguiente entorno:

- **Sistema Operativo**: Ubuntu Linux
- **Shell**: Bash 5.2.21
- **Fecha de Desarrollo**: Mayo 2025


## Componentes

### Amazon S3

Amazon S3 sirve como el repositorio principal para todo nuestro contenido estático y los archivos PDF generados por el sistema. Este componente fundamental actúa como la columna vertebral del almacenamiento de nuestra aplicación, garantizando la disponibilidad y durabilidad de los datos en todo momento, incluso bajo cargas de trabajo intensas.

La configuración implementada en S3 incluye políticas de seguridad rigurosas que restringen el acceso directo a los recursos. Hemos establecido reglas de control de acceso que permiten la interacción únicamente a través de nuestra distribución de CloudFront, añadiendo una capa adicional de seguridad a nuestros activos y previniendo el acceso no autorizado desde fuentes externas.

Para optimizar el rendimiento y los costos, hemos implementado políticas de ciclo de vida que gestionan automáticamente el almacenamiento de los archivos. Los PDFs generados se almacenan inicialmente en la clase Standard de S3 y, después de un período definido, se transfieren automáticamente a clases de almacenamiento más económicas como Infrequent Access, manteniendo un equilibrio óptimo entre accesibilidad y costo.

### Amazon CloudFront

Implementamos CloudFront como nuestra solución integral de entrega de contenido, proporcionando una red global de distribución que acerca los recursos a los usuarios finales. Este servicio actúa como la primera línea de interacción con nuestra aplicación, optimizando los tiempos de carga y mejorando significativamente la experiencia de usuario en diversas ubicaciones geográficas.

La configuración de CloudFront ha sido cuidadosamente diseñada para distribuir eficientemente tanto el contenido web estático desde S3 como proporcionar acceso seguro a nuestra API GraphQL. Utilizamos políticas de caché personalizadas para diferentes tipos de contenido, asegurando que los recursos estáticos se sirvan rápidamente mientras que las solicitudes dinámicas se procesan adecuadamente.

La integración de CloudFront con AWS WAF proporciona una capa adicional de seguridad contra amenazas web comunes. Esta combinación nos permite implementar protecciones avanzadas sin comprometer el rendimiento, garantizando que la entrega de contenido permanezca rápida y segura incluso frente a intentos de ataques distribuidos o exploits conocidos.

### AWS WAF

AWS WAF constituye nuestro escudo de protección web, proporcionando una capa crítica de seguridad para toda la infraestructura expuesta públicamente. Este servicio analiza continuamente el tráfico entrante, identificando y bloqueando posibles amenazas antes de que puedan alcanzar nuestros servidores o impactar la disponibilidad del servicio.

Hemos configurado WAF con un conjunto completo de reglas de seguridad para defender contra una amplia gama de vectores de ataque. Las protecciones implementadas incluyen filtros contra inyección SQL, cross-site scripting (XSS), y otros exploits web comunes que podrían comprometer la integridad de nuestra aplicación o los datos de los usuarios.

Un componente crucial de nuestra implementación de WAF es el mecanismo de limitación de tasas, diseñado para mitigar efectivamente ataques de denegación de servicio. Este sistema identifica patrones de tráfico anormales y limita automáticamente las solicitudes excesivas, asegurando que los recursos permanezcan disponibles para usuarios legítimos incluso durante intentos de saturación de la infraestructura.

### AWS AppSync

AppSync representa el núcleo de nuestra capa de API, implementando una interfaz GraphQL robusta y flexible que unifica todas las operaciones de datos en un solo punto de acceso. Este servicio permite a nuestra aplicación web realizar consultas complejas y obtener exactamente la información necesaria en cada petición, reduciendo la sobrecarga de red y optimizando la experiencia del usuario.

La implementación de AppSync incluye un esquema GraphQL cuidadosamente diseñado que modela perfectamente nuestro dominio de aplicación. Hemos definido tipos, consultas, mutaciones y suscripciones que capturan toda la funcionalidad necesaria, facilitando a los desarrolladores frontales la interacción con los datos de manera intuitiva y predecible.

La integración de AppSync con servicios como Lambda para el procesamiento de datos y Cognito para la autenticación crea un ecosistema seguro y eficiente. Esta arquitectura garantiza que cada solicitud sea autenticada apropiadamente y que solo los usuarios autorizados puedan acceder a las funcionalidades específicas según sus roles y permisos, manteniendo la integridad y confidencialidad de los datos en todo momento.

### AWS Lambda

Las funciones Lambda constituyen el cerebro operativo de nuestra aplicación, proporcionando una capa de procesamiento sin servidor altamente escalable y rentable. Este enfoque nos permite ejecutar código en respuesta a eventos sin preocuparnos por la administración de servidores, obteniendo escalabilidad automática y un modelo de pago por uso que optimiza nuestros costos operativos.

Hemos organizado nuestras funciones Lambda siguiendo principios de responsabilidad única, con cada función diseñada para realizar una tarea específica de manera eficiente. Algunas procesan solicitudes de la API, otras ejecutan la lógica de negocio principal, y un conjunto específico se encarga de activar y coordinar tareas en ECS Fargate cuando se requiere la generación de horarios, garantizando una arquitectura modular y mantenible.

La seguridad es prioritaria en nuestra implementación de Lambda, con cada función configurada con roles IAM específicos siguiendo el principio de mínimo privilegio. Estos roles limitan cuidadosamente los permisos de cada función a exactamente lo que necesita para operar, reduciendo la superficie de ataque y asegurando que, incluso en caso de compromiso, el impacto potencial permanezca contenido y limitado.

### Amazon Cognito

Utilizamos Cognito como nuestra solución integral de gestión de identidad y acceso, proporcionando un sistema robusto que maneja todos los aspectos de autenticación y autorización. Este servicio nos permite ofrecer a los usuarios una experiencia de registro e inicio de sesión fluida mientras mantenemos estándares rigurosos de seguridad, cumpliendo con mejores prácticas de la industria en protección de credenciales.

La implementación incluye flujos de autenticación personalizados que se adaptan a diferentes casos de uso, desde el acceso estándar con correo electrónico y contraseña hasta opciones de identidad federada que permiten a los usuarios acceder mediante cuentas existentes en plataformas como Google o Facebook. También hemos configurado políticas de contraseñas fuertes y mecanismos de verificación multi-factor para cuentas sensibles.

Cognito se integra perfectamente con nuestra API de AppSync, actuando como guardián que asegura que cada solicitud sea debidamente autenticada. El sistema de tokens JWT proporciona una capa de seguridad que permite verificar la identidad del usuario y sus permisos en cada operación, facilitando la implementación de controles de acceso granulares basados en roles y atributos específicos del usuario.

### Amazon ECR

El Elastic Container Registry actúa como nuestro repositorio centralizado y seguro para almacenar, administrar y desplegar imágenes Docker. Este componente crítico de nuestra infraestructura proporciona un punto de control para garantizar que solo las imágenes apropiadamente verificadas y autorizadas sean utilizadas en nuestros procesos de generación de horarios, manteniendo la consistencia y seguridad en todos los despliegues.

Hemos implementado un proceso completo de seguridad en ECR que incluye el escaneo automático de imágenes para detectar vulnerabilidades. Cada imagen subida al repositorio es analizada utilizando herramientas avanzadas que identifican posibles problemas de seguridad en el código base, las dependencias y las configuraciones, permitiéndonos abordar proactivamente cualquier riesgo antes del despliegue.

Las políticas de ciclo de vida configuradas en ECR nos permiten gestionar eficientemente el almacenamiento y las versiones de las imágenes. Estas reglas automatizan la retención de un número específico de versiones históricas mientras eliminan imágenes obsoletas, optimizando costos de almacenamiento y manteniendo un registro claro de los cambios realizados a lo largo del tiempo para facilitar la trazabilidad y el control de versiones.

### AWS Fargate

Fargate representa nuestra solución de computación sin servidor para ejecutar contenedores, eliminando la necesidad de administrar la infraestructura subyacente. Este servicio nos permite definir y desplegar nuestras tareas de generación de horarios con precisión, especificando exactamente los recursos de CPU y memoria necesarios para cada operación sin la sobrecarga de gestionar servidores o clústeres.

Nuestras tareas de Fargate ejecutan un sofisticado script de Python con Selenium que automatiza completamente el proceso de generación de horarios. Este script interactúa programáticamente con la interfaz web del generador, seleccionando parámetros, procesando datos y extrayendo resultados, todo dentro de un entorno controlado y reproducible que garantiza consistencia en cada ejecución.

Toda la operación de Fargate se realiza dentro de un entorno VPC cuidadosamente diseñado con controles de acceso estrictos. Hemos implementado grupos de seguridad específicos, listas de control de acceso a la red, y rutas definidas que permiten solo las conexiones esenciales, asegurando que nuestros contenedores operen en un entorno aislado y seguro mientras mantienen acceso controlado a los recursos externos necesarios para completar sus tareas.

### Amazon DynamoDB

Nuestra implementación de DynamoDB proporciona una base de datos NoSQL completamente administrada, altamente disponible y escalable que almacena eficientemente todo el historial de generación de horarios. Este servicio nos ofrece un rendimiento consistente de milisegundos a cualquier escala, permitiéndonos mantener tiempos de respuesta rápidos incluso durante períodos de uso intensivo al inicio de cada semestre académico.

El esquema de datos en DynamoDB ha sido cuidadosamente diseñado para optimizar los patrones de acceso específicos de nuestra aplicación. Utilizamos una combinación estratégica de claves de partición y ordenación que permiten consultas altamente eficientes por ID de usuario y otros criterios relevantes, facilitando la recuperación rápida de historiales completos o sesiones específicas según las necesidades del usuario.

Para garantizar la integridad y disponibilidad de los datos, hemos configurado DynamoDB con capacidades avanzadas de recuperación. La configuración de recuperación en un punto en el tiempo (PITR) nos permite restaurar la tabla a cualquier momento dentro de los últimos 35 días, proporcionando protección robusta contra eliminaciones accidentales, modificaciones erróneas o cualquier otra situación que pudiera comprometer la integridad de nuestros registros históricos.

## Proceso de Generación de Horarios

1. El usuario solicita la generación de un horario a través de la interfaz web.
2. La solicitud es procesada por AppSync y Lambda.
3. Lambda activa una tarea de ECS Fargate.
4. La tarea de Fargate ejecuta el script de Python en contenedores con Selenium.
5. El PDF generado se almacena en S3.
6. Los metadatos del horario y el enlace de descarga se almacenan en DynamoDB.
7. El usuario puede acceder al horario generado a través de la interfaz web.

## Despliegue

1. Inicializar Terraform:
   terraform init

2. Crear un workspace (opcional):
   terraform workspace new dev

3. Planificar el despliegue:
   terraform plan
4. Aplicar la configuración:
   terraform apply


5. Construir y subir la imagen Docker:
   ```bash
   cd docker
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_REPOSITORY_URL>
   docker build -t <ECR_REPOSITORY_URL>:latest .
   docker push <ECR_REPOSITORY_URL>:latest
   ```
