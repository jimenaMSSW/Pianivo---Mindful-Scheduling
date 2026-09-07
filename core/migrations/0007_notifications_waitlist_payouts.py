from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0006_deposits_and_refunds'),
    ]

    operations = [
        migrations.AddField(
            model_name='appointment',
            name='employee_earnings_amount',
            field=models.PositiveIntegerField(default=0, help_text='Employee earnings in cents.'),
        ),
        migrations.AddField(
            model_name='appointment',
            name='payout_status',
            field=models.CharField(default='unpaid', max_length=30),
        ),
        migrations.AlterField(
            model_name='appointment',
            name='status',
            field=models.CharField(choices=[('pending', 'Pending'), ('confirmed', 'Confirmed'), ('completed', 'Completed'), ('cancelled', 'Cancelled'), ('no_show', 'No-show'), ('rejected', 'Rejected')], default='pending', max_length=20),
        ),
        migrations.AddField(
            model_name='business',
            name='employees_keep_own_client_profits',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='employee',
            name='commission_percentage',
            field=models.PositiveSmallIntegerField(default=0, help_text='Employee commission percentage from 0 to 100.'),
        ),
        migrations.AddField(
            model_name='payment',
            name='employee_earnings_amount',
            field=models.PositiveIntegerField(default=0, help_text='Employee earnings in cents.'),
        ),
        migrations.AddField(
            model_name='payment',
            name='payout_status',
            field=models.CharField(default='unpaid', max_length=30),
        ),
        migrations.CreateModel(
            name='AppNotification',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('audience', models.CharField(choices=[('client', 'Client'), ('employee', 'Employee'), ('owner', 'Owner'), ('business', 'Business'), ('all', 'All')], max_length=20)),
                ('recipient_name', models.CharField(blank=True, max_length=100)),
                ('title', models.CharField(max_length=120)),
                ('message', models.TextField()),
                ('is_read', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('business', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='notifications', to='core.business')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='WaitlistEntry',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('customer_name', models.CharField(max_length=100)),
                ('customer_email', models.EmailField(blank=True, max_length=254, null=True)),
                ('service_name', models.CharField(max_length=120)),
                ('preferred_start_time', models.DateTimeField()),
                ('status', models.CharField(choices=[('waiting', 'Waiting'), ('contacted', 'Contacted'), ('booked', 'Booked'), ('removed', 'Removed')], default='waiting', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('business', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='waitlist_entries', to='core.business')),
            ],
            options={
                'ordering': ['preferred_start_time'],
            },
        ),
    ]
