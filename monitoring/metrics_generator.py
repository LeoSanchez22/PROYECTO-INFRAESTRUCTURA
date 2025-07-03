#!/usr/bin/env python3
"""
Script para generar métricas de prueba en CloudWatch para visualizar en Grafana
"""

import boto3
import random
import time
import json
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

class MetricsGenerator:
    def __init__(self, region='us-east-1'):
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.region = region
        
    def send_custom_metric(self, namespace, metric_name, value, unit='Count', dimensions=None):
        """Envía una métrica personalizada a CloudWatch"""
        try:
            metric_data = {
                'MetricName': metric_name,
                'Value': value,
                'Unit': unit,
                'Timestamp': datetime.utcnow()
            }
            
            if dimensions:
                metric_data['Dimensions'] = dimensions
            
            response = self.cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[metric_data]
            )
            
            print(f"✅ Métrica enviada: {namespace}/{metric_name} = {value} {unit}")
            return response
            
        except ClientError as e:
            print(f"❌ Error enviando métrica: {e}")
            return None
    
    def generate_application_metrics(self):
        """Genera métricas para la aplicación de horarios"""
        namespace = 'UPAO/ScheduleGenerator'
        
        # Usuarios activos
        active_users = random.randint(10, 100)
        self.send_custom_metric(namespace, 'ActiveUsers', active_users, 'Count')
        
        # Consultas de horarios
        schedule_queries = random.randint(5, 50)
        self.send_custom_metric(namespace, 'ScheduleQueries', schedule_queries, 'Count')
        
        # Tiempo de respuesta de la API
        response_time = random.uniform(100, 500)
        self.send_custom_metric(namespace, 'APIResponseTime', response_time, 'Milliseconds')
        
        # Errores
        error_count = random.randint(0, 5)
        self.send_custom_metric(namespace, 'ErrorCount', error_count, 'Count')
        
        # Uso de memoria
        memory_usage = random.uniform(30, 80)
        self.send_custom_metric(namespace, 'MemoryUsage', memory_usage, 'Percent')
        
        # CPU Usage
        cpu_usage = random.uniform(10, 70)
        self.send_custom_metric(namespace, 'CPUUsage', cpu_usage, 'Percent')
        
    def generate_cloudfront_metrics(self):
        """Genera métricas para CloudFront"""
        namespace = 'AWS/CloudFront'
        
        # Requests
        requests = random.randint(100, 1000)
        self.send_custom_metric(namespace, 'Requests', requests, 'Count', 
                               [{'Name': 'DistributionId', 'Value': 'EXSP94HC3HBKW'}])
        
        # Cache Hit Rate
        cache_hit_rate = random.uniform(70, 95)
        self.send_custom_metric(namespace, 'CacheHitRate', cache_hit_rate, 'Percent',
                               [{'Name': 'DistributionId', 'Value': 'EXSP94HC3HBKW'}])
        
        # Origin Latency
        origin_latency = random.uniform(50, 200)
        self.send_custom_metric(namespace, 'OriginLatency', origin_latency, 'Milliseconds',
                               [{'Name': 'DistributionId', 'Value': 'EXSP94HC3HBKW'}])
    
    def generate_s3_metrics(self):
        """Genera métricas para S3"""
        namespace = 'AWS/S3'
        
        # Requests
        get_requests = random.randint(50, 300)
        self.send_custom_metric(namespace, 'NumberOfObjects', get_requests, 'Count',
                               [{'Name': 'BucketName', 'Value': 'leocorp-frontend-v2-default-e6459d08'}])
        
        # Bucket Size
        bucket_size = random.uniform(1000000, 5000000)  # 1-5 MB
        self.send_custom_metric(namespace, 'BucketSizeBytes', bucket_size, 'Bytes',
                               [{'Name': 'BucketName', 'Value': 'leocorp-frontend-v2-default-e6459d08'}])
    
    def generate_lambda_metrics(self):
        """Genera métricas para Lambda"""
        namespace = 'AWS/Lambda'
        
        # Invocations
        invocations = random.randint(20, 100)
        self.send_custom_metric(namespace, 'Invocations', invocations, 'Count',
                               [{'Name': 'FunctionName', 'Value': 'schedule-generator'}])
        
        # Duration
        duration = random.uniform(500, 3000)
        self.send_custom_metric(namespace, 'Duration', duration, 'Milliseconds',
                               [{'Name': 'FunctionName', 'Value': 'schedule-generator'}])
        
        # Errors
        errors = random.randint(0, 3)
        self.send_custom_metric(namespace, 'Errors', errors, 'Count',
                               [{'Name': 'FunctionName', 'Value': 'schedule-generator'}])
    
    def run_continuous_generation(self, duration_minutes=10):
        """Ejecuta la generación continua de métricas"""
        print(f"🚀 Iniciando generación de métricas por {duration_minutes} minutos...")
        
        end_time = datetime.now() + timedelta(minutes=duration_minutes)
        
        while datetime.now() < end_time:
            print(f"\n📊 Generando métricas - {datetime.now().strftime('%H:%M:%S')}")
            
            # Generar métricas de diferentes servicios
            self.generate_application_metrics()
            self.generate_cloudfront_metrics()
            self.generate_s3_metrics()
            self.generate_lambda_metrics()
            
            print("⏰ Esperando 30 segundos antes de la siguiente generación...")
            time.sleep(30)
        
        print("✅ Generación de métricas completada!")

def main():
    generator = MetricsGenerator()
    
    print("🎯 Generador de Métricas CloudWatch para Grafana")
    print("=" * 50)
    
    # Generar métricas iniciales
    generator.generate_application_metrics()
    generator.generate_cloudfront_metrics()
    generator.generate_s3_metrics()
    generator.generate_lambda_metrics()
    
    print("\n🔄 ¿Quieres generar métricas continuas? (y/n)")
    response = input().lower()
    
    if response == 'y':
        generator.run_continuous_generation(duration_minutes=5)
    else:
        print("✅ Métricas iniciales generadas. Revisa Grafana!")

if __name__ == "__main__":
    main()
