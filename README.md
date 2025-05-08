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


## Componentes

### Amazon S3
- Aloja contenido web estático.
- Almacena los horarios generados en formato PDF.
- Configurado con políticas de bucket adecuadas.
- Acceso restringido únicamente a través de CloudFront.

### Amazon CloudFront
- Distribuye contenido web globalmente.
- Conecta con S3 para contenido estático.
- Conecta con AppSync para acceso a la API.
- Protegido por AWS WAF.

### AWS WAF
- Protege CloudFront contra exploits web comunes.
- Implementa limitación de tasas.
- Utiliza conjuntos de reglas administradas por AWS.

### AWS AppSync
- Proporciona una API GraphQL.
- Conecta con Lambda para el procesamiento de datos.
- Asegurado con autenticación de Cognito.

### AWS Lambda
- Procesa solicitudes de la API.
- Ejecuta la lógica de negocio.
- Activa tareas de ECS Fargate.
- Configurado con roles IAM adecuados.

### Amazon Cognito
- Gestiona la autenticación de usuarios.
- Asegura el acceso a la API de AppSync.

### Amazon ECR
- Almacena imágenes Docker para el generador de horarios.
- Implementa escaneo de imágenes y políticas de ciclo de vida.

### AWS Fargate
- Ejecuta tareas de generación de horarios en contenedores.
- Ejecuta un script de Python con Selenium.
- Opera en un entorno VPC seguro.

### Amazon DynamoDB
- Almacena el historial de generación de horarios.
- Permite consultas eficientes por ID de usuario.
- Configurado con recuperación en un punto en el tiempo.

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
   cd docker aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_REPOSITORY_URL> docker build -t <ECR_REPOSITORY_URL>:latest . docker push <ECR_REPOSITORY_URL>:latest