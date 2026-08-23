from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0004_paymentaccount_payment'),
    ]

    operations = [
        migrations.CreateModel(
            name='OwnerSubscription',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('email', models.EmailField(db_index=True, max_length=254)),
                ('name', models.CharField(blank=True, max_length=100)),
                ('business_code', models.CharField(db_index=True, max_length=32)),
                ('firebase_uid', models.CharField(blank=True, max_length=255)),
                ('stripe_checkout_session_id', models.CharField(max_length=255, unique=True)),
                ('stripe_customer_id', models.CharField(blank=True, db_index=True, max_length=255)),
                ('stripe_subscription_id', models.CharField(blank=True, db_index=True, max_length=255)),
                ('status', models.CharField(default='checkout_started', max_length=50)),
                ('current_period_end', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
