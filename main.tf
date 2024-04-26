# Dostawca AWS - region us-east-1
provider "aws" {
  region = "us-east-1"
  shared_credentials_files = [".aws/config/credentials"]  # Ścieżka do pliku z danymi uwierzytelniającymi
}

# Parę kluczy AWS
resource "aws_key_pair" "key_pair" {
  key_name   = "my-key-pair"  # Nazwa pary kluczy
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCizAH9jKRUW7qsIuLsegei1xn3p/HeAKtSM3tMSBr6sJXz3iMK5QxpQUyLsie82cu/ZFBJxbJRrwRagNdkCK2+49FyP3j56+3ciFc3s68LoaQiMkZOGiR1ZyVjLqkwAVXo1LLFWSj9EVXZ9n7vLEJtT0VAhbWKgnKKSEpnBgNBlkCBohnyZKiEbw3VMqTwgDAYMOr+w23bGFcsVCEg1wwV1GETYPcXhl/rEXOj6TrHR+pMgJqPcXnQcZuOFmEhOpe9ks3CkZfn/ViHLGYnXYEg+rZeEL/q09iEFLgaUur96RXn90ujXhJfT1BW9cMzFXhzbeaaZyv/QKloGk1FSr/3"
}

# Instancja AWS EC2
resource "aws_instance" "ec2" {
  ami                    = "ami-0b0dcb5067f052a63"  # ID obrazu AMI
  instance_type          = "t2.micro"  # Typ instancji
  key_name               = aws_key_pair.key_pair.key_name  # Nazwa pary kluczy
  vpc_security_group_ids = ["${aws_security_group.rtp03-sg.id}"]  # Identyfikator grupy zabezpieczeń VPC
  subnet_id              = "${aws_subnet.rtp03-public_subent_01.id}"  # Identyfikator podsieci
}

# Zasób null dla przykładu
resource "null_resource" "example" {
  # Wykonawca zdalny
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /app",  # Tworzenie katalogu /app
      "sudo chmod 777 -R /app"  # Nadawanie uprawnień do katalogu /app
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(".aws/config/labsuser.pem")  # Ścieżka do klucza prywatnego
      host        = aws_instance.ec2.public_ip  # Publiczny adres IP instancji EC2
    }
  }

  # Wykonawca plików
  provisioner "file" {
    source      = "./project"  # Lokalna ścieżka do pliku
    destination = "/app"  # Docelowa ścieżka na instancji
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(".aws/config/labsuser.pem")  # Ścieżka do klucza prywatnego
      host        = aws_instance.ec2.public_ip  # Publiczny adres IP instancji EC2
    }
  }

  # Ponowny wykonawca zdalny
  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install docker -y",  # Instalacja Docker na instancji
      "sudo service docker start",  # Uruchomienie usługi Docker
      "sudo curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose",  # Pobranie Docker Compose
      "sudo usermod -aG docker $USER",  # Dodanie użytkownika do grupy Docker
      "sudo chmod +x /usr/local/bin/docker-compose",  # Nadanie uprawnień wykonywalnych dla Docker Compose
      "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose",  # Tworzenie dowiązania symbolicznego dla Docker Compose
      "cd /app/project",  # Przejście do katalogu /app/project
      "sudo docker-compose up --build -d"  # Uruchomienie kontenerów Docker
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(".aws/config/labsuser.pem")  # Ścieżka do klucza prywatnego
      host        = aws_instance.ec2.public_ip  # Publiczny adres IP instancji EC2
    }
  }
}

# Grupa zabezpieczeń AWS
resource "aws_security_group" "rtp03-sg" {
  name = "rtp03-sg"  # Nazwa grupy zabezpieczeń
  vpc_id = "${aws_vpc.rtp03-vpc.id}"  # Identyfikator VPC

  ingress {
      from_port   = 80  # Port źródłowy
      to_port     = 80  # Port docelowy
      protocol    = "tcp"  # Protokół
      cidr_blocks = ["0.0.0.0/0"]  # Adresy IP, z których akceptowane są połączenia
  }

  ingress {
      from_port   = 3000  # Port źródłowy
      to_port     = 3000  # Port docelowy
      protocol    = "tcp"  # Protokół
      cidr_blocks = ["0.0.0.0/0"]  # Adresy IP, z których akceptowane są połączenia
  }

  egress {
      from_port   = 0  # Port źródłowy
      to_port     = 0  # Port docelowy
      protocol    = "-1"  # Wszystkie protokoły
      cidr_blocks = ["0.0.0.0/0"]  # Adresy IP, do których są wysyłane pakiety
  }

  tags = {
      Name = "ssh-sg"  # Etykieta
  }
}

# VPC AWS
resource "aws_vpc" "rtp03-vpc" {
    cidr_block = "10.1.0.0/16"  # Adresy IP dla VPC
    tags = {
      Name = "rpt03-vpc"  # Etykieta
    }
  
}

# Podsieć publiczna AWS
resource "aws_subnet" "rtp03-public_subent_01" {
    vpc_id                  = "${aws_vpc.rtp03-vpc.id}"  # Identyfikator VPC
    cidr_block              = "10.1.1.0/24"  # Adresy IP dla podsieci
    map_public_ip_on_launch = "true"  # Przypisanie publicznego adresu IP podczas uruchamiania instancji
    availability_zone       = "us-east-1a"  # Strefa dostępności
    tags = {
      Name = "rtp03-public_subent_01"  # Etykieta
    }
  
}

# Bramka internetowa AWS
resource "aws_internet_gateway" "rtp03-igw" {
    vpc_id = "${aws_vpc.rtp03-vpc.id}"  # Identyfikator VPC
    tags = {
      Name = "rtp03-igw"  # Etykieta
    }
}

# Tablica tras AWS
resource "aws_route_table" "rtp03-public-rt" {
    vpc_id = "${aws_vpc.rtp03-vpc.id}"  # Identyfikator VPC
    route {
        cidr_block = "0.0.0.0/0"  # Adresy IP docelowe
        gateway_id = "${aws_internet_gateway.rtp03-igw.id}"  # Identyfikator bramki internetowej
    }
    tags = {
      Name = "rtp03-public-rt"  # Etykieta
    }
}

# Powiązanie tablicy tras z podsiecią publiczną
resource "aws_route_table_association" "rtp03-rta-public-subent-1" {
    subnet_id        = "${aws_subnet.rtp03-public_subent_01.id}"  # Identyfikator podsieci
    route_table_id   = "${aws_route_table.rtp03-public-rt.id}"  # Identyfikator tablicy tras
}

# Klastry ECS AWS
resource "aws_ecs_cluster" "app_cluster" {
  name = "my-ecs-cluster"  # Nazwa klastra
}

# Definicja zadania ECS AWS
resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-app-task"  # Nazwa rodziny
  execution_role_arn       = aws_iam_role.task_execution_role.arn  # ARN roli wykonawczej
  network_mode             = "awsvpc"  # Tryb sieciowy
  requires_compatibilities = ["FARGATE"]  # Kompatybilności
  cpu                      = "256"  # Ilość CPU
  memory                   = "512"  # Ilość pamięci

  container_definitions = jsonencode([{
    name      = "my-app-container"  # Nazwa kontenera
    image     = "./project"  # Obraz kontenera
    cpu       = 256  # Ilość CPU dla kontenera
    memory    = 512  # Ilość pamięci dla kontenera
    essential = true  # Czy kontener jest niezbędny
    portMappings = [{
      containerPort = 80  # Port kontenera
      protocol      = "tcp"  # Protokół
    }]
  }])
}

# Usługa ECS AWS
resource "aws_ecs_service" "app_service" {
  name            = "my-app-service"  # Nazwa usługi
  cluster         = aws_ecs_cluster.app_cluster.id  # Identyfikator klastra
  task_definition = aws_ecs_task_definition.app_task.arn  # ARN definicji zadania
  desired_count   = 1  # Pożądana liczba instancji
  launch_type     = "FARGATE"  # Typ uruchomienia

  network_configuration {
    security_groups = ["${aws_security_group.rtp03-sg.id}"]  # Identyfikator grupy zabezpieczeń
    subnets         = ["${aws_subnet.rtp03-public_subent_01.id}"]  # Identyfikator podsieci
    assign_public_ip = true  # Przypisanie publicznego adresu IP
  }
}

# Rola IAM AWS
resource "aws_iam_role" "task_execution_role" {
  name               = "my-ecs-task-execution-role"  # Nazwa roli
  assume_role_policy = jsonencode({  # Polityka przyznawania roli
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Dołączenie polityki roli IAM
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.task_execution_role.name  # Nazwa roli
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"  # ARN polityki
}