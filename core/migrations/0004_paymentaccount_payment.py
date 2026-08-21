# Generated for Stripe payment readiness.

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0003_alter_message_options_alter_appointment_status_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='PaymentAccount',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('stripe_account_id', models.CharField(blank=True, max_length=255)),
                ('charges_enabled', models.BooleanField(default=False)),
                ('payouts_enabled', models.BooleanField(default=False)),
                ('details_submitted', models.BooleanField(default=False)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('business', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='payment_account', to='core.business')),
            ],
        ),
        migrations.CreateModel(
            name='Payment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('customer_name', models.CharField(max_length=100)),
                ('customer_email', models.EmailField(blank=True, max_length=254, null=True)),
                ('amount', models.PositiveIntegerField(help_text='Smallest currency unit, such as cents.')),
                ('currency', models.CharField(default='usd', max_length=3)),
                ('status', models.CharField(choices=[('created', 'Created'), ('requires_payment_method', 'Requires payment method'), ('requires_confirmation', 'Requires confirmation'), ('requires_action', 'Requires action'), ('processing', 'Processing'), ('succeeded', 'Succeeded'), ('canceled', 'Canceled'), ('failed', 'Failed')], default='created', max_length=30)),
                ('payment_method', models.CharField(choices=[('card', 'Card'), ('klarna', 'Klarna'), ('unknown', 'Unknown')], default='unknown', max_length=30)),
                ('stripe_payment_intent_id', models.CharField(max_length=255, unique=True)),
                ('stripe_latest_charge_id', models.CharField(blank=True, max_length=255)),
                ('last_error', models.TextField(blank=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('appointment', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='payments', to='core.appointment')),
                ('business', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='payments', to='core.business')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
